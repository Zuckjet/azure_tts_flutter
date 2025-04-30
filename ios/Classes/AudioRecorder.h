//
// Copyright (c) Microsoft. All rights reserved.
// Licensed under the MIT license. See LICENSE.md file in the project root for full license information.
//

#import <Foundation/Foundation.h>
#import <MicrosoftCognitiveServicesSpeech/SPXSpeechApi.h>

typedef NS_ENUM(NSInteger, RecordingInterruptionReason) {
    RecordingInterruptionReasonUnknown = 0,
    RecordingInterruptionReasonInvalidBuffer,
    RecordingInterruptionReasonQueueError,
    RecordingInterruptionReasonFileError,
    RecordingInterruptionReasonSessionError,
    RecordingInterruptionReasonSystemInterruption,
    RecordingStoppedByPanic,
    RecordingStartedByPanic
};

@protocol AudioRecorderDelegate <NSObject>
- (void)audioRecorderDidEncounterInterruption:(RecordingInterruptionReason)reason errorMessage:(NSString *)message;
@end

@interface AudioRecorder : NSObject

// Fix: Use proper parameter naming format with external parameter name for the second parameter
- (instancetype)initWithPushStream:(SPXPushAudioInputStream *)stream filePath:(NSString *)filePath;

@property (nonatomic, assign, readonly) BOOL isRunning;
@property (nonatomic, weak) id<AudioRecorderDelegate> delegate;

- (void)record;
- (void)stop;

@end