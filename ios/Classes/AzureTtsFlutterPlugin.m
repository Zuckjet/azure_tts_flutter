#import "AzureTtsFlutterPlugin.h"
#import "AudioRecorder.h"
#import <MicrosoftCognitiveServicesSpeech/SPXSpeechApi.h>

#import <AVFoundation/AVFoundation.h>

@interface AzureTtsFlutterPlugin () {
    AudioRecorder *recorder;
}

@end


@implementation AzureTtsFlutterPlugin


dispatch_queue_t serialQueue = nil;
bool end = false;

FlutterMethodChannel* channel;

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
      channel = [FlutterMethodChannel
      methodChannelWithName:@"azure_tts_flutter"
            binaryMessenger:[registrar messenger]];
  AzureTtsFlutterPlugin* instance = [[AzureTtsFlutterPlugin alloc] init];
  [registrar addMethodCallDelegate:instance channel:channel];
    
    serialQueue = dispatch_queue_create("com.example.serialQueue", DISPATCH_QUEUE_SERIAL);
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
  if ([@"getPlatformVersion" isEqualToString:call.method]) {
    result([@"iOS " stringByAppendingString:[[UIDevice currentDevice] systemVersion]]);
  } else if ([@"startRecognize" isEqualToString:call.method]) {
    NSLog(@"call method in oc");
    NSString *key = call.arguments[@"key"];
    NSString *region = call.arguments[@"region"];
    NSString *lang = call.arguments[@"lang"];
      dispatch_async( dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
          [self startRecognize:key:region:lang];
      });
  } else if ([@"stopRecognize" isEqualToString:call.method]) {
      NSLog(@"receive stop method");
      // [speechRecognizer stopContinuousRecognition];
      
      dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
        dispatch_sync(serialQueue, ^{
          end = true;
          NSLog(@"call stop method");
        });
      });
      
  } else {
      result(FlutterMethodNotImplemented);
  }
}

- (void)startRecognize: (NSString *) key : (NSString *) region : (NSString *) lang {
  SPXSpeechConfiguration *speechConfig = [[SPXSpeechConfiguration alloc] initWithSubscription:key region:region];
    if (!speechConfig) {
        NSLog(@"Could not load speech config");
        return;
    }

    SPXPushAudioInputStream *stream = [[SPXPushAudioInputStream alloc] init];
    self->recorder = [[AudioRecorder alloc]initWithPushStream:stream];
    NSLog(@"recognize start 1112223333");
    [self->recorder record];
    SPXAudioConfiguration *audioConfig = [[SPXAudioConfiguration alloc]initWithStreamInput:stream];

    SPXSpeechRecognizer* speechRecognizer = [[SPXSpeechRecognizer alloc] initWithSpeechConfiguration:speechConfig language:@"zh-CN" audioConfiguration:audioConfig];
    if (!speechRecognizer) {
        NSLog(@"Could not create speech recognizer");
        return;
    }
    // [self->recorder record];

    [speechRecognizer addRecognizingEventHandler: ^ (SPXSpeechRecognizer *recognizer, SPXSpeechRecognitionEventArgs *eventArgs) {
        NSLog(@"Received intermediate result event. SessionId: %@, recognition result:%@. Status %ld. offset %llu duration %llu resultid:%@", eventArgs.sessionId, eventArgs.result.text, (long)eventArgs.result.reason, eventArgs.result.offset, eventArgs.result.duration, eventArgs.result.resultId);
        [channel invokeMethod:@"speech.onRecognizing"
              arguments:eventArgs.result.text
                 result:^(id _Nullable result) {
                    // You can handle the response from Flutter side if needed
                 }];
    }];
    [speechRecognizer addRecognizedEventHandler: ^ (SPXSpeechRecognizer *recognizer, SPXSpeechRecognitionEventArgs *eventArgs) {
        NSLog(@"Received final result event. SessionId: %@, recognition result:%@. Status %ld. offset %llu duration %llu resultid:%@", eventArgs.sessionId, eventArgs.result.text, (long)eventArgs.result.reason, eventArgs.result.offset, eventArgs.result.duration, eventArgs.result.resultId);
        
        [channel invokeMethod:@"speech.onResult"
              arguments:eventArgs.result.text
                 result:^(id _Nullable result) {
                    // You can handle the response from Flutter side if needed
                 }];
    }];

    // Session stopped callback to recognize stream has ended
    [speechRecognizer addSessionStoppedEventHandler: ^ (SPXRecognizer *recognizer, SPXSessionEventArgs *eventArgs) {
        NSLog(@"Received session stopped event. SessionId: %@", eventArgs.sessionId);
        end = true;
    }];

    // Start recognizing
    [speechRecognizer startContinuousRecognition];
    // [NSThread sleepForTimeInterval:30.0f];
    while (1) {
      [NSThread sleepForTimeInterval:1.0f];
      __block BOOL loopEnd = false;
      dispatch_sync(serialQueue, ^{
        loopEnd = end;
      });
      if (loopEnd) {
          NSLog(@"end loop");
          break;
      }
    }
    
    [speechRecognizer stopContinuousRecognition];
    [self->recorder stop];
    NSLog(@"recognize end 111");
    dispatch_sync(serialQueue, ^{
      end = false;
      NSLog(@"reset variable");
    });
}
@end
