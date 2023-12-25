#import "AzureTtsFlutterPlugin.h"
#import "AudioRecorder.h"
#import <MicrosoftCognitiveServicesSpeech/SPXSpeechApi.h>

@implementation AzureTtsFlutterPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FlutterMethodChannel* channel = [FlutterMethodChannel
      methodChannelWithName:@"azure_tts_flutter"
            binaryMessenger:[registrar messenger]];
  AzureTtsFlutterPlugin* instance = [[AzureTtsFlutterPlugin alloc] init];
  [registrar addMethodCallDelegate:instance channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
  if ([@"getPlatformVersion" isEqualToString:call.method]) {
    result([@"iOS " stringByAppendingString:[[UIDevice currentDevice] systemVersion]]);
  } else if ([@"startRecognize" isEqualToString:call.method]) {
    NSLog(@"call method in oc");
    NSString *key = call.arguments[@"key"];
    NSString *region = call.arguments[@"region"];
    NSString *lang = call.arguments[@"lang"];
    [self startRecognize:key:region:lang];
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
    NSLog(@"start recognize lineeeeee");
    // should handle here
    SPXPushAudioInputStream *stream = [[SPXPushAudioInputStream alloc] init];
    AudioRecorder *recorder = [[AudioRecorder alloc]initWithPushStream:stream];
    SPXAudioConfiguration *audioConfig = [[SPXAudioConfiguration alloc]initWithStreamInput:stream];

    SPXSpeechRecognizer* speechRecognizer = [[SPXSpeechRecognizer alloc] initWithSpeechConfiguration:speechConfig language:lang audioConfiguration:audioConfig];
    if (!speechRecognizer) {
        NSLog(@"Could not create speech recognizer");
        return;
    }
    [recorder record];
    if (!speechRecognizer) {
        NSLog(@"Could not create speech recognizer");
        return;
    }
    
    [speechRecognizer addRecognizingEventHandler: ^ (SPXSpeechRecognizer *recognizer, SPXSpeechRecognitionEventArgs *eventArgs) {
           NSLog(@"Received intermediate result event. SessionId: %@, recognition result:%@. Status %ld. offset %llu duration %llu resultid:%@", eventArgs.sessionId, eventArgs.result.text, (long)eventArgs.result.reason, eventArgs.result.offset, eventArgs.result.duration, eventArgs.result.resultId);
       }];
    
    [speechRecognizer addRecognizedEventHandler: ^ (SPXSpeechRecognizer *recognizer, SPXSpeechRecognitionEventArgs *eventArgs) {
            NSLog(@"Received final result event. SessionId: %@, recognition result:%@. Status %ld. offset %llu duration %llu resultid:%@", eventArgs.sessionId, eventArgs.result.text, (long)eventArgs.result.reason, eventArgs.result.offset, eventArgs.result.duration, eventArgs.result.resultId);
        
        // ...
        }];
    
    __block bool end = false;
    [speechRecognizer addSessionStoppedEventHandler: ^ (SPXRecognizer *recognizer, SPXSessionEventArgs *eventArgs) {
            NSLog(@"Received session stopped event. SessionId: %@", eventArgs.sessionId);
        end = true;
        }];
    
    [speechRecognizer startContinuousRecognition];
    
    while (end == false) {
        [NSThread sleepForTimeInterval:6.0f];
        [speechRecognizer stopContinuousRecognition];
    }
    
}

@end
