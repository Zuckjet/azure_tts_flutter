//
// Copyright (c) Microsoft. All rights reserved.
// Licensed under the MIT license. See LICENSE.md file in the project root for
// full license information.
//

#import "AudioRecorder.h"
#import <AVFoundation/AVFoundation.h>

static const int kNumberBuffers = 3;

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
                            stream filePath:(NSString *)filePath {
  if (self = [super init]) {
    if (stream == nil) {
      NSLog(@"Error: Push stream cannot be nil");
      return nil;
    }
    if (filePath.length == 0) {
      NSLog(@"Error: File path cannot be empty");
      return nil;
    }
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
      return nil;
    }

    for (int i = 0; i < kNumberBuffers; i++) {
      status = AudioQueueAllocateBuffer(queueRef, 3200, &buffers[i]);
      if (status != noErr) {
        NSLog(@"Error allocating buffer %d: %d", i, (int)status);
        AudioQueueDispose(queueRef,
                          true); // Clean up queue if buffer allocation fails
        queueRef = NULL;
        return nil;
      }
      status = AudioQueueEnqueueBuffer(queueRef, buffers[i], 0, NULL);
      if (status != noErr) {
        NSLog(@"Error enqueuing buffer %d: %d", i, (int)status);
        // Consider further cleanup or error handling if initial enqueue fails
        return nil;
      }
    }

    //  NSString *fileString = [AudioRecorder createFilePath];
    NSString *fileString = filePath;
    NSLog(@"fileString is %@", fileString);

    CFStringRef fileUrl = CFStringCreateWithCString(
        NULL, [fileString UTF8String], kCFStringEncodingUTF8);
    if (fileUrl == NULL) {
      NSLog(@"Error creating file URL");
      AudioQueueDispose(queueRef, true);
      queueRef = NULL;
      return nil;
    }
    CFURLRef audioFileURL = CFURLCreateWithFileSystemPath(
        kCFAllocatorDefault, fileUrl, kCFURLPOSIXPathStyle, false);
    if (audioFileURL == NULL) {
      NSLog(@"Failed to create CFURL from file path");
      CFRelease(fileUrl);
      AudioQueueDispose(queueRef, true);
      queueRef = NULL;
      return nil;
    }
    status =
        AudioFileCreateWithURL(audioFileURL, kAudioFileCAFType, &recordFormat,
                               kAudioFileFlags_EraseFile, &recordFile);
    CFRelease(fileUrl);
    CFRelease(audioFileURL);

    if (status != noErr) {
      NSLog(@"Error creating audio file: %d", (int)status);
      AudioQueueDispose(queueRef, true);
      queueRef = NULL;
      return nil;
    }
     [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleAudioSessionInterruption:)
                                                 name:AVAudioSessionInterruptionNotification
                                               object:nil];
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [self stop];
  if (queueRef) {
    AudioQueueDispose(queueRef, true);
    queueRef = NULL;
  }
}

- (void)handleAudioSessionInterruption:(NSNotification *)notification {
  NSInteger type = [notification.userInfo[AVAudioSessionInterruptionTypeKey] integerValue];
  
  if (type == AVAudioSessionInterruptionTypeBegan) {
    // Report the interruption
    [self reportInterruptionWithReason:RecordingInterruptionReasonSystemInterruption
                          errorMessage:@"Recording interrupted by system"];
    
    // Stop recording if it's running
    if (self.isRunning) {
      [self stop];
    }
  }
}

- (void)reportInterruptionWithReason:(RecordingInterruptionReason)reason errorMessage:(NSString *)message {
  if ([self.delegate respondsToSelector:@selector(audioRecorderDidEncounterInterruption:errorMessage:)]) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [self.delegate audioRecorderDidEncounterInterruption:reason errorMessage:message];
    });
  }
}

static void recorderCallBack(void *aqData, AudioQueueRef inAQ,
                             AudioQueueBufferRef inBuffer,
                             const AudioTimeStamp *timestamp,
                             UInt32 inNumPackets,
                             const AudioStreamPacketDescription *inPacketDesc) {
  AudioRecorder *recorder = (__bridge AudioRecorder *)aqData;
  @try {
    // Check recorder validity and running state
    if (!recorder || !recorder.isRunning) {
      return;
    }

    // 确保缓冲区有效
    if (!inBuffer || !inBuffer->mAudioData ||
        inBuffer->mAudioDataByteSize == 0) {
      NSLog(@"Invalid audio buffer (recorder is running)");
       [recorder reportInterruptionWithReason:RecordingInterruptionReasonInvalidBuffer
                              errorMessage:@"Invalid audio buffer received"];
      if (recorder.isRunning) {
        OSStatus enqueueStatus =
            AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, NULL);
        if (enqueueStatus != noErr) {
          NSLog(@"Error re-enqueuing invalid buffer: %d", (int)enqueueStatus);
          [recorder reportInterruptionWithReason:RecordingInterruptionReasonQueueError
                                  errorMessage:[NSString stringWithFormat:@"Failed to enqueue buffer: %d", (int)enqueueStatus]];
          // Consider triggering stop/error handling here as queue might stall
          // Consider forcing stop if there's a serious queue error
          if (enqueueStatus == kAudioQueueErr_InvalidBuffer || 
              enqueueStatus == kAudioQueueErr_InvalidRunState) {
            dispatch_async(dispatch_get_main_queue(), ^{
              [recorder stop];
            });
          }
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
         [recorder reportInterruptionWithReason:RecordingInterruptionReasonQueueError
                                errorMessage:[NSString stringWithFormat:@"Failed to enqueue buffer: %d", (int)enqueueStatus]];
        // Stop recording if critical queue error
        if (enqueueStatus == kAudioQueueErr_InvalidBuffer || 
            enqueueStatus == kAudioQueueErr_InvalidRunState) {
          dispatch_async(dispatch_get_main_queue(), ^{
            [recorder stop];
          });
        }
      }
    }

    // 检查文件句柄
    if (recorder->recordFile == NULL) {
      NSLog(@"Record file is null - skipping file write");
       [recorder reportInterruptionWithReason:RecordingInterruptionReasonFileError
                              errorMessage:@"Record file handle is null"];
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
        NSString *errorMsg = @"Unknown file error";
        switch (status) {
        case kAudioFileInvalidPacketOffsetError: // -38
          errorMsg = @"Audio File Error: Invalid packet offset";
          break;
        case kAudioFileUnspecifiedError:
          errorMsg = @"Audio File Error: Unspecified error";
          break;
        case kAudioFileNotOpenError:
          errorMsg = @"Audio File Error: File not open";
          break;
        case kAudioFilePermissionsError:
          errorMsg = @"Audio File Error: Permission denied";
          break;
        default:
          errorMsg = [NSString stringWithFormat:@"Audio File Write Error: Status %d", (int)status];
          break;
        }
        return;
      }

      // 更新包计数
      recorder->recordPacket += inNumPackets;
    }
  } @catch (NSException *exception) {
    NSLog(@"Exception in recorderCallBack: %@", exception);
    [recorder reportInterruptionWithReason:RecordingInterruptionReasonUnknown
                            errorMessage:[NSString stringWithFormat:@"Exception: %@", exception.reason]];
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
     [self reportInterruptionWithReason:RecordingInterruptionReasonSessionError
                         errorMessage:[NSString stringWithFormat:@"Failed to set audio session: %@", sessionError.localizedDescription]];
    return;
  }

  [[AVAudioSession sharedInstance] setActive:true error:&sessionError];
  if (sessionError) {
    NSLog(@"Failed to activate audio session: %@", sessionError);
     [self reportInterruptionWithReason:RecordingInterruptionReasonSessionError
                         errorMessage:[NSString stringWithFormat:@"Failed to activate audio session: %@", sessionError.localizedDescription]];
    return;
  }

  // 启动录音队列
  OSStatus status = AudioQueueStart(queueRef, NULL);
  if (status != noErr) {
    NSLog(@"Failed to start audio queue: %d", (int)status);
     [self reportInterruptionWithReason:RecordingInterruptionReasonQueueError
                         errorMessage:[NSString stringWithFormat:@"Failed to start audio queue: %d", (int)status]];
    return;
  }

  _isRunning = true;
}

- (void)stop {
  if (self.isRunning) {
    _isRunning = false;
    // 停止队列前检查其状态
    if (queueRef) {
      OSStatus status = AudioQueueStop(queueRef, true);
      if (status != noErr) {
        NSLog(@"Failed to stop audio queue: %d", (int)status);
      }
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

    // 重置音频会话
    [[AVAudioSession sharedInstance]
          setActive:false
        withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation
              error:nil];
  }
}

@end