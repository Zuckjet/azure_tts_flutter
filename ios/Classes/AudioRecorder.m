//
// Copyright (c) Microsoft. All rights reserved.
// Licensed under the MIT license. See LICENSE.md file in the project root for
// full license information.
//

#import "AudioRecorder.h"
#import <AVFoundation/AVFoundation.h>

static const int kNumberBuffers = 3;
static AudioQueueRef recordQueue = NULL;

@interface AudioRecorder () {
  AudioQueueRef queueRef;
  AudioQueueBufferRef buffers[kNumberBuffers];
  SPXPushAudioInputStream *pushStream;
  AudioFileID recordFile;
  SInt64 recordPacket;
}

@property(nonatomic, assign) SInt64 currPacket;

@end

@implementation AudioRecorder

- (instancetype)initWithPushStream:(SPXPushAudioInputStream *)
                            stream:(NSString *)filePath {
  if (self = [super init]) {
    AudioStreamBasicDescription recordFormat = {0};
    recordFormat.mFormatID = kAudioFormatLinearPCM;
    recordFormat.mSampleRate = 16000;
    recordFormat.mChannelsPerFrame = 1;
    recordFormat.mBitsPerChannel = 16;
    recordFormat.mFramesPerPacket = 1;
    recordFormat.mBytesPerFrame = recordFormat.mBytesPerPacket =
        (recordFormat.mBitsPerChannel / 8) * recordFormat.mChannelsPerFrame;
    recordFormat.mFormatFlags =
        kLinearPCMFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;

    self->pushStream = stream;
    self.currPacket = 0;

    OSStatus status = AudioQueueNewInput(&recordFormat, recorderCallBack,
                                         (__bridge void *)self, NULL,
                                         kCFRunLoopCommonModes, 0, &queueRef);
    if (status != noErr) {
      NSLog(@"new input error");
    }

    for (int i = 0; i < kNumberBuffers; i++) {
      AudioQueueAllocateBuffer(queueRef, 3200, &buffers[i]);
      AudioQueueEnqueueBuffer(queueRef, buffers[i], 0, NULL);
    }

    if (status != noErr) {
      NSLog(@"create recorder file failure");
    }

    //  NSString *fileString = [AudioRecorder createFilePath];
    NSString *fileString = filePath;
    NSLog(@"fileString is %@", fileString);

    CFStringRef fileUrl = CFStringCreateWithCString(
        NULL, [fileString UTF8String], kCFStringEncodingUTF8);
    CFURLRef audioFileURL = CFURLCreateWithFileSystemPath(
        kCFAllocatorDefault, fileUrl, kCFURLPOSIXPathStyle, false);
    AudioFileCreateWithURL(audioFileURL, kAudioFileCAFType, &recordFormat,
                           kAudioFileFlags_EraseFile, &recordFile);
    CFRelease(audioFileURL);
  }
  return self;
}

- (void)dealloc {
  AudioQueueDispose(queueRef, true);
}

static void recorderCallBack(void *aqData, AudioQueueRef inAQ,
                             AudioQueueBufferRef inBuffer,
                             const AudioTimeStamp *timestamp,
                             UInt32 inNumPackets,
                             const AudioStreamPacketDescription *inPacketDesc) {
  @try {
    AudioRecorder *recorder = (__bridge AudioRecorder *)aqData;

    // Check recorder validity and running state
    if (!recorder || !recorder.isRunning) {
      return;
    }

    // 确保缓冲区有效
    if (!inBuffer || !inBuffer->mAudioData ||
        inBuffer->mAudioDataByteSize == 0) {
      NSLog(@"Invalid audio buffer (recorder is running)");
      if (recorder.isRunning) {
        OSStatus enqueueStatus =
            AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, NULL);
        if (enqueueStatus != noErr) {
          NSLog(@"Error re-enqueuing invalid buffer: %d", (int)enqueueStatus);
          // Consider triggering stop/error handling here as queue might stall
        }
      }
      return;
    }

    // 处理音频数据流
    NSData *data = [[NSData alloc]
        initWithBytesNoCopy:(void *)inBuffer->mAudioData
                     length:(NSUInteger)inBuffer->mAudioDataByteSize
               freeWhenDone:false];
    [recorder->pushStream write:data];

    // 继续录音
    if (recorder.isRunning) {
      OSStatus enqueueStatus = AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, NULL);
      if (enqueueStatus != noErr) {
        NSLog(@"Failed to enqueue buffer: %d", (int)enqueueStatus);
      }
    }

    // 检查文件句柄
    if (recorder->recordFile == NULL) {
      NSLog(@"Record file is null - skipping file write");
      return;
    }

    // 写入文件
    if (inNumPackets > 0) {
      OSStatus status = AudioFileWritePackets(
          recorder->recordFile, FALSE, inBuffer->mAudioDataByteSize,
          inPacketDesc, recorder->recordPacket, &inNumPackets,
          inBuffer->mAudioData);

      if (status != noErr) {
        // 特定错误处理
        switch (status) {
        case kAudioFileInvalidPacketOffsetError: // -38
          NSLog(@"Audio File Error: Invalid packet offset");
          break;
        case kAudioFileUnspecifiedError:
          NSLog(@"Audio File Error: Unspecified error");
          break;
        case kAudioFileNotOpenError:
          NSLog(@"Audio File Error: File not open");
          break;
        case kAudioFilePermissionsError:
          NSLog(@"Audio File Error: Permission denied");
          break;
        default:
          NSLog(@"Audio File Write Error: Status %d", (int)status);
          break;
        }
        return;
      }

      // 更新包计数
      recorder->recordPacket += inNumPackets;
    }
  } @catch (NSException *exception) {
    NSLog(@"Exception in recorderCallBack: %@", exception);
  }
}

- (void)record {
  if (self.isRunning) {
    return;
  }

  // 设置音频会话
  NSError *sessionError = nil;
  [[AVAudioSession sharedInstance]
      setCategory:AVAudioSessionCategoryPlayAndRecord
      withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker |
                  AVAudioSessionCategoryOptionAllowBluetooth
            error:&sessionError];
  if (sessionError) {
    NSLog(@"Failed to set audio session category: %@", sessionError);
    return;
  }

  [[AVAudioSession sharedInstance] setActive:true error:&sessionError];
  if (sessionError) {
    NSLog(@"Failed to activate audio session: %@", sessionError);
    return;
  }

  // 重新创建音频文件（如果已关闭）
  if (recordFile == NULL) {
    AudioStreamBasicDescription recordFormat = {0};
    recordFormat.mFormatID = kAudioFormatLinearPCM;
    recordFormat.mSampleRate = 16000;
    recordFormat.mChannelsPerFrame = 1;
    recordFormat.mBitsPerChannel = 16;
    recordFormat.mFramesPerPacket = 1;
    recordFormat.mBytesPerFrame = recordFormat.mBytesPerPacket =
        (recordFormat.mBitsPerChannel / 8) * recordFormat.mChannelsPerFrame;
    recordFormat.mFormatFlags =
        kLinearPCMFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;

    NSString *fileString = [AudioRecorder createFilePath]; // 每次创建新文件
    NSLog(@"Creating new audio file at: %@", fileString);

    CFStringRef fileUrl = CFStringCreateWithCString(
        NULL, [fileString UTF8String], kCFStringEncodingUTF8);
    CFURLRef audioFileURL = CFURLCreateWithFileSystemPath(
        kCFAllocatorDefault, fileUrl, kCFURLPOSIXPathStyle, false);

    OSStatus createStatus =
        AudioFileCreateWithURL(audioFileURL, kAudioFileCAFType, &recordFormat,
                               kAudioFileFlags_EraseFile, &recordFile);

    CFRelease(fileUrl);
    CFRelease(audioFileURL);

    if (createStatus != noErr) {
      NSLog(@"Failed to create audio file: %d", (int)createStatus);
      return;
    }

    // 重置包计数
    recordPacket = 0;
  }

  // 启动录音队列
  OSStatus status = AudioQueueStart(queueRef, NULL);
  if (status != noErr) {
    NSLog(@"Failed to start audio queue: %d", (int)status);
    return;
  }

  _isRunning = true;
}

- (void)stop {
  if (self.isRunning) {
    _isRunning = false;
    // 停止队列前检查其状态
    OSStatus status = AudioQueueStop(queueRef, true);
    if (status != noErr) {
      NSLog(@"Failed to stop audio queue: %d", (int)status);
    }
    // 关闭音频文件
    if (recordFile != NULL) {
      OSStatus closeStatus = AudioFileClose(recordFile);
      if (closeStatus != noErr) {
        NSLog(@"Failed to close audio file: %d", (int)closeStatus);
      }
      recordFile = NULL;
    }

    // 重置记录变量
    recordPacket = 0;

    // 重新创建音频队列，以便下次使用
    AudioStreamBasicDescription recordFormat = {0};
    recordFormat.mFormatID = kAudioFormatLinearPCM;
    recordFormat.mSampleRate = 16000;
    recordFormat.mChannelsPerFrame = 1;
    recordFormat.mBitsPerChannel = 16;
    recordFormat.mFramesPerPacket = 1;
    recordFormat.mBytesPerFrame = recordFormat.mBytesPerPacket =
        (recordFormat.mBitsPerChannel / 8) * recordFormat.mChannelsPerFrame;
    recordFormat.mFormatFlags =
        kLinearPCMFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;

    // 释放旧队列
    AudioQueueDispose(queueRef, true);

    // 创建新队列
    OSStatus newStatus = AudioQueueNewInput(
        &recordFormat, recorderCallBack, (__bridge void *)self, NULL,
        kCFRunLoopCommonModes, 0, &queueRef);
    if (newStatus != noErr) {
      NSLog(@"Failed to create new audio queue: %d", (int)newStatus);
    }

    // 分配新缓冲区
    for (int i = 0; i < kNumberBuffers; i++) {
      AudioQueueAllocateBuffer(queueRef, 3200, &buffers[i]);
      AudioQueueEnqueueBuffer(queueRef, buffers[i], 0, NULL);
    }

    // 重置音频会话
    [[AVAudioSession sharedInstance]
          setActive:false
        withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation
              error:nil];
  }
}

+ (NSString *)createFilePath {
  NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
  dateFormatter.dateFormat = @"yyyy_MM_dd__HH_mm_ss";
  NSString *date = [dateFormatter stringFromDate:[NSDate date]];

  NSArray *searchPaths = NSSearchPathForDirectoriesInDomains(
      NSDocumentDirectory, NSUserDomainMask, YES);

  NSString *documentPath =
      [[searchPaths objectAtIndex:0] stringByAppendingPathComponent:@"Voice"];

  // 先创建子目录.
  // 注意,若果直接调用AudioFileCreateWithURL创建一个不存在的目录创建文件会失败
  NSFileManager *fileManager = [NSFileManager defaultManager];
  if (![fileManager fileExistsAtPath:documentPath]) {
    [fileManager createDirectoryAtPath:documentPath
           withIntermediateDirectories:YES
                            attributes:nil
                                 error:nil];
  }

  NSString *fullFileName = [NSString stringWithFormat:@"%@.caf", date];
  NSString *filePath =
      [documentPath stringByAppendingPathComponent:fullFileName];
  return filePath;
}

@end
