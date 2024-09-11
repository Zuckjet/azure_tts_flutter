//
// Copyright (c) Microsoft. All rights reserved.
// Licensed under the MIT license. See LICENSE.md file in the project root for full license information.
//

#import "AudioRecorder.h"
#import <AVFoundation/AVFoundation.h>

static const int kNumberBuffers = 3;
static AudioQueueRef recordQueue = NULL;
static AudioFileID recordFile = NULL;
static SInt64 recordPacket = 0;

@interface AudioRecorder () {
    AudioQueueRef               queueRef;
    AudioQueueBufferRef         buffers[kNumberBuffers];
    SPXPushAudioInputStream     *pushStream;
}

@property (nonatomic, assign) SInt64 currPacket;

@end

@implementation AudioRecorder

- (instancetype)initWithPushStream:(SPXPushAudioInputStream *)stream : (NSString *) filePath
{
    if (self = [super init]) {
        AudioStreamBasicDescription recordFormat = {0};
        recordFormat.mFormatID = kAudioFormatLinearPCM;
        recordFormat.mSampleRate = 16000;
        recordFormat.mChannelsPerFrame = 1;
        recordFormat.mBitsPerChannel = 16;
        recordFormat.mFramesPerPacket = 1;
        recordFormat.mBytesPerFrame = recordFormat.mBytesPerPacket = (recordFormat.mBitsPerChannel / 8) * recordFormat.mChannelsPerFrame;
        recordFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;

        self->pushStream = stream;
        self.currPacket = 0;

        OSStatus status = AudioQueueNewInput(&recordFormat,
                                             recorderCallBack,
                                             (__bridge void *)self,
                                             NULL,
                                             kCFRunLoopCommonModes,
                                             0,
                                             &queueRef);
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
    
    CFStringRef fileUrl = CFStringCreateWithCString (NULL, [fileString   UTF8String], kCFStringEncodingUTF8);
    CFURLRef audioFileURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, fileUrl, kCFURLPOSIXPathStyle, false);
    AudioFileCreateWithURL(audioFileURL, kAudioFileCAFType, &recordFormat, kAudioFileFlags_EraseFile, &recordFile);
    CFRelease(audioFileURL);



    }
    return self;
}

- (void)dealloc {
    AudioQueueDispose(queueRef, true);
}

static void recorderCallBack(void *aqData,
                             AudioQueueRef inAQ,
                             AudioQueueBufferRef inBuffer,
                             const AudioTimeStamp *timestamp,
                             UInt32 inNumPackets,
                             const AudioStreamPacketDescription *inPacketDesc) {
    AudioRecorder *recorder = (__bridge AudioRecorder *)aqData;

    NSData* data = [[NSData alloc] initWithBytesNoCopy:(void*)inBuffer->mAudioData
                                                length:(NSUInteger)inBuffer->mAudioDataByteSize
                                          freeWhenDone:false];
    [recorder->pushStream write:data];

    if (recorder.isRunning) {
        AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, NULL);
    }


    if (inNumPackets > 0) {
        // NSLog(@"inNumPackets is %d", inNumPackets);
        // Write packets to a file
        OSStatus status = AudioFileWritePackets(recordFile, FALSE, inBuffer->mAudioDataByteSize, inPacketDesc, recordPacket, &inNumPackets, inBuffer->mAudioData);
        assert(status == noErr);
        
        // Increment packet count
        recordPacket += inNumPackets;
    }
}

- (void)record {
    if (self.isRunning) {
        return;
    }
    // test
    // [[AVAudioSession sharedInstance] setInputGain:0.5 error:nil];
    // [[AVAudioSession sharedInstance] setMode:AVAudioSessionModeVoiceChat error:nil];

    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    [[AVAudioSession sharedInstance] setActive:true error:nil];

    OSStatus status = AudioQueueStart(queueRef, NULL);
    if (status != noErr) {
        NSLog(@"start queue failure");
        return;
    }
    _isRunning = true;



    // ...


    // AudioStreamBasicDescription recordFormat = {0};
    // recordFormat.mFormatID = kAudioFormatLinearPCM;
    // recordFormat.mSampleRate = 16000;
    // recordFormat.mChannelsPerFrame = 1;
    // recordFormat.mBitsPerChannel = 16;
    // recordFormat.mFramesPerPacket = 1;
    // recordFormat.mBytesPerFrame = recordFormat.mBytesPerPacket = (recordFormat.mBitsPerChannel / 8) * recordFormat.mChannelsPerFrame;
    // recordFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;

    // NSString *fileString = [AudioRecorder createFilePath];
    // NSLog(@"fileString is %@", fileString);
    
    // CFStringRef fileUrl = CFStringCreateWithCString (NULL, [fileString   UTF8String], kCFStringEncodingUTF8);
    // CFURLRef audioFileURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, fileUrl, kCFURLPOSIXPathStyle, false);
    // AudioFileCreateWithURL(audioFileURL, kAudioFileCAFType, &recordFormat, kAudioFileFlags_EraseFile, &recordFile);
    // CFRelease(audioFileURL);
}

- (void)stop
{
    if (self.isRunning) {
        AudioQueueStop(queueRef, true);
        _isRunning = false;

        [[AVAudioSession sharedInstance] setActive:false
                                       withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation
                                             error:nil];

        AudioQueueDispose(queueRef, true);
        AudioFileClose(recordFile);
        recordFile = NULL;
        recordPacket = 0;

    }
}

+ (NSString *)createFilePath {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"yyyy_MM_dd__HH_mm_ss";
    NSString *date = [dateFormatter stringFromDate:[NSDate date]];
    
    NSArray *searchPaths    = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                                  NSUserDomainMask,
                                                                  YES);
    
    NSString *documentPath  = [[searchPaths objectAtIndex:0] stringByAppendingPathComponent:@"Voice"];
    
    // 先创建子目录. 注意,若果直接调用AudioFileCreateWithURL创建一个不存在的目录创建文件会失败
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:documentPath]) {
        [fileManager createDirectoryAtPath:documentPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    NSString *fullFileName  = [NSString stringWithFormat:@"%@.caf",date];
    NSString *filePath      = [documentPath stringByAppendingPathComponent:fullFileName];
    return filePath;
}

@end
