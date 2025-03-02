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

FlutterMethodChannel *channel;
SPXSpeechRecognizer *speechRecognizer;

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  channel = [FlutterMethodChannel methodChannelWithName:@"azure_tts_flutter"
                                        binaryMessenger:[registrar messenger]];
  AzureTtsFlutterPlugin *instance = [[AzureTtsFlutterPlugin alloc] init];
  [registrar addMethodCallDelegate:instance channel:channel];

  serialQueue =
      dispatch_queue_create("com.example.serialQueue", DISPATCH_QUEUE_SERIAL);
}

- (void)handleMethodCall:(FlutterMethodCall *)call
                  result:(FlutterResult)result {
  if ([@"getPlatformVersion" isEqualToString:call.method]) {
    result([@"iOS "
        stringByAppendingString:[[UIDevice currentDevice] systemVersion]]);
  } else if ([@"getBluetoothDevices" isEqualToString:call.method]) {
    result([self getBluetoothDevices]);
  } else if ([@"startRecognize" isEqualToString:call.method]) {
    NSString *key = call.arguments[@"key"];
    NSString *region = call.arguments[@"region"];
    NSString *lang = call.arguments[@"lang"];
    NSString *filePath = call.arguments[@"filePath"];
    dispatch_async(
        dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
          [self startRecognize:key:region:lang:filePath];
        });
  } else if ([@"stopRecognize" isEqualToString:call.method]) {
    dispatch_async(
        dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
          [speechRecognizer stopContinuousRecognition];
          [self->recorder stop];
        });
  } else if ([@"startRecognizeWithFile" isEqualToString:call.method]) {
    NSLog(@"call method in oc");
    NSString *key = call.arguments[@"key"];
    NSString *region = call.arguments[@"region"];
    NSString *lang = call.arguments[@"lang"];
    NSString *filePath = call.arguments[@"filePath"];
    dispatch_async(
        dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
          [self startRecognizeWithFile:key:region:lang:filePath];
        });
  }

  else {
    result(FlutterMethodNotImplemented);
  }
}

- (void)startRecognize:(NSString *)
                   key:(NSString *)region
                      :(NSString *)lang
                      :(NSString *)filePath {
  NSLog(@"startRecognize 111");
  SPXSpeechConfiguration *speechConfig =
      [[SPXSpeechConfiguration alloc] initWithSubscription:key region:region];
  if (!speechConfig) {
    return;
  }

  SPXPushAudioInputStream *stream = [[SPXPushAudioInputStream alloc] init];
  self->recorder = [[AudioRecorder alloc] initWithPushStream:stream:filePath];
  [self->recorder record];
  SPXAudioConfiguration *audioConfig =
      [[SPXAudioConfiguration alloc] initWithStreamInput:stream];

  NSArray *languagess = @[ @"zh-CN", @"en-US", @"ja-JP", @"de-DE" ];
  SPXAutoDetectSourceLanguageConfiguration *autoDetectSourceLanguageConfig =
      [[SPXAutoDetectSourceLanguageConfiguration alloc] init:languagess];

  speechRecognizer = [[SPXSpeechRecognizer alloc]
                initWithSpeechConfiguration:speechConfig
      autoDetectSourceLanguageConfiguration:autoDetectSourceLanguageConfig
                         audioConfiguration:audioConfig];
  if (!speechRecognizer) {
    return;
  }
  // [self->recorder record];

  [speechRecognizer addRecognizingEventHandler:^(
                        SPXSpeechRecognizer *recognizer,
                        SPXSpeechRecognitionEventArgs *eventArgs) {
    NSLog(@"Received intermediate result event. SessionId: %@, recognition "
          @"result:%@. Status %ld. offset %llu duration %llu resultid:%@",
          eventArgs.sessionId, eventArgs.result.text,
          (long)eventArgs.result.reason, eventArgs.result.offset,
          eventArgs.result.duration, eventArgs.result.resultId);
    dispatch_async(dispatch_get_main_queue(), ^{
      [channel
          invokeMethod:@"speech.onRecognizing"
             arguments:eventArgs.result.text
                result:^(id _Nullable result){
                    // You can handle the response from Flutter side if needed
                }];
    });
  }];
  [speechRecognizer addRecognizedEventHandler:^(
                        SPXSpeechRecognizer *recognizer,
                        SPXSpeechRecognitionEventArgs *eventArgs) {
    NSLog(@"Received final result event. SessionId: %@, recognition "
          @"result:%@. Status %ld. offset %llu duration %llu resultid:%@",
          eventArgs.sessionId, eventArgs.result.text,
          (long)eventArgs.result.reason, eventArgs.result.offset,
          eventArgs.result.duration, eventArgs.result.resultId);

    dispatch_async(dispatch_get_main_queue(), ^{
      [channel
          invokeMethod:@"speech.onResult"
             arguments:eventArgs.result.text
                result:^(id _Nullable result){
                    // You can handle the response from Flutter side if needed
                }];
    });
  }];

  // Session stopped callback to recognize stream has ended
  [speechRecognizer addSessionStoppedEventHandler:^(
                        SPXRecognizer *recognizer,
                        SPXSessionEventArgs *eventArgs) {
    NSLog(@"Received session stopped event. SessionId: %@",
          eventArgs.sessionId);
    end = true;

    dispatch_async(dispatch_get_main_queue(), ^{
      [channel
          invokeMethod:@"speech.onSessionStopped"
             arguments:eventArgs.sessionId
                result:^(id _Nullable result){
                    // You can handle the response from Flutter side if needed
                }];
    });
  }];

  // Start recognizing
  [speechRecognizer startContinuousRecognition];
}

- (void)startRecognizeWithFiles:(NSString *)
                            key:(NSString *)region
                               :(NSString *)lang
                               :(NSString *)filePath {
  NSBundle *mainBundle = [NSBundle mainBundle];
  NSString *weatherFiles = [mainBundle pathForResource:@"outputs"
                                                ofType:@"wav"];
  NSLog(@"weatherFile path: %@", weatherFiles);
  SPXAudioConfiguration *weatherAudioSource =
      [[SPXAudioConfiguration alloc] initWithWavFileInput:weatherFiles];
  if (!weatherAudioSource) {
    return;
  }

  SPXSpeechConfiguration *speechConfig =
      [[SPXSpeechConfiguration alloc] initWithSubscription:key region:region];

  NSArray *languagess = @[ @"zh-CN", @"en-US", @"ja-JP", @"de-DE" ];
  SPXAutoDetectSourceLanguageConfiguration *autoDetectSourceLanguageConfig =
      [[SPXAutoDetectSourceLanguageConfiguration alloc] init:languagess];

  SPXSpeechRecognizer *speechRecognizer = [[SPXSpeechRecognizer alloc]
                initWithSpeechConfiguration:speechConfig
      autoDetectSourceLanguageConfiguration:autoDetectSourceLanguageConfig
                         audioConfiguration:weatherAudioSource];

  SPXSpeechRecognitionResult *speechResult = [speechRecognizer recognizeOnce];
  if (SPXResultReason_Canceled == speechResult.reason) {
    SPXCancellationDetails *details = [[SPXCancellationDetails alloc]
        initFromCanceledRecognitionResult:speechResult];
  } else if (SPXResultReason_RecognizedSpeech == speechResult.reason) {
    // NSLog(@"Speech recognition result received: %@", speechResult.text);
  } else {
    // NSLog(@"There was an error.");
  }
}

- (void)startRecognizeWithFile:(NSString *)
                           key:(NSString *)region
                              :(NSString *)lang
                              :(NSString *)filePath {

  NSBundle *mainBundle = [NSBundle mainBundle];

  NSURL *targetUrl = [NSURL URLWithString:filePath];
  NSError *error = nil;

  AVAudioFile *audioFile =
      [[AVAudioFile alloc] initForReading:targetUrl
                             commonFormat:AVAudioPCMFormatInt16
                              interleaved:NO
                                    error:&error];
  if (error) {
    NSLog(@"Error while opening file: %@", error);
    return;
  }

  // check the format of the file
  NSAssert(1 == audioFile.fileFormat.channelCount, @"Bad channel count");
  NSAssert(16000 == audioFile.fileFormat.sampleRate, @"Unexpected sample rate");

  // set up the stream
  SPXAudioStreamFormat *audioFormat = [[SPXAudioStreamFormat alloc]
      initUsingPCMWithSampleRate:audioFile.fileFormat.sampleRate
                   bitsPerSample:16
                        channels:1];
  SPXPushAudioInputStream *stream;
  stream = [[SPXPushAudioInputStream alloc] initWithAudioFormat:audioFormat];

  SPXAudioConfiguration *audioConfig =
      [[SPXAudioConfiguration alloc] initWithStreamInput:stream];
  if (!audioConfig) {
    NSLog(@"Error creating stream!");
    return;
  }

  SPXSpeechConfiguration *speechConfig =
      [[SPXSpeechConfiguration alloc] initWithSubscription:key region:region];
  if (!speechConfig) {
    NSLog(@"Could not load speech config");
    return;
  }

  // ...
  NSArray *languagess = @[ @"zh-CN", @"en-US", @"ja-JP", @"de-DE" ];
  SPXAutoDetectSourceLanguageConfiguration *autoDetectSourceLanguageConfig =
      [[SPXAutoDetectSourceLanguageConfiguration alloc] init:languagess];

  SPXSpeechRecognizer *speechRecognizer = [[SPXSpeechRecognizer alloc]
                initWithSpeechConfiguration:speechConfig
      autoDetectSourceLanguageConfiguration:autoDetectSourceLanguageConfig
                         audioConfiguration:audioConfig];
  if (!speechRecognizer) {
    NSLog(@"Could not create speech recognizer");
    return;
  }

  // connect callbacks
  [speechRecognizer
      addRecognizingEventHandler:^(SPXSpeechRecognizer *recognizer,
                                   SPXSpeechRecognitionEventArgs *eventArgs){
      }];

  [speechRecognizer addRecognizedEventHandler:^(
                        SPXSpeechRecognizer *recognizer,
                        SPXSpeechRecognitionEventArgs *eventArgs) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [channel
          invokeMethod:@"recognizeFile.onResult"
             arguments:eventArgs.result.text
                result:^(id _Nullable result){
                    // You can handle the response from Flutter side if needed
                }];
    });
  }];

  // start recognizing
  // [self updateRecognitionStatusText:(@"Recognizing from push stream...")];
  [speechRecognizer startContinuousRecognition];

  // set up the buffer fo push data into the stream
  const AVAudioFrameCount nBytesToRead = 5000;
  const NSInteger bytesPerFrame =
      audioFile.fileFormat.streamDescription->mBytesPerFrame;
  AVAudioPCMBuffer *buffer =
      [[AVAudioPCMBuffer alloc] initWithPCMFormat:audioFile.fileFormat
                                    frameCapacity:nBytesToRead / bytesPerFrame];

  NSAssert(1 == buffer.stride, @"only one channel allowed");
  NSAssert(nil != buffer.int16ChannelData, @"assure correct format");

  // push data to stream
  while (1) {
    NSError *bufferError = nil;
    bool success = [audioFile readIntoBuffer:buffer error:&bufferError];
    if (!success) {
      NSLog(@"Read error on stream: %@", bufferError);
      [stream close];
      break;
    } else {
      NSInteger nBytesRead = [buffer frameLength] * bytesPerFrame;
      if (0 == nBytesRead) {
        [stream close];
        break;
      }

      // NSLog(@"Read %d bytes from file", (int)nBytesRead);

      NSData *data = [NSData dataWithBytesNoCopy:buffer.int16ChannelData[0]
                                          length:nBytesRead
                                    freeWhenDone:NO];
      // NSLog(@"%d bytes data returned", (int)[data length]);

      [stream write:data];
      // NSLog(@"Wrote %d bytes to stream", (int)[data length]);
    }

    [NSThread sleepForTimeInterval:0.1f];
  }

  [speechRecognizer stopContinuousRecognition];

  dispatch_async(dispatch_get_main_queue(), ^{
    [channel
        invokeMethod:@"recognizeFile.onStop"
           arguments:@"stop"
              result:^(id _Nullable result){
                  // You can handle the response from Flutter side if needed
              }];
  });
}

- (NSString *)getBluetoothDevices {
  NSMutableArray<NSDictionary *> *bluetoothDevices = [NSMutableArray array];
  NSArray *availInputs = [[AVAudioSession sharedInstance] availableInputs];
  NSArray *headphoneKeywords = @[
    @"airpods", @"buds", @"headphone", @"headphones", @"earphone", @"earphones",
    @"earpods", @"tws", @"freestyle", @"freebuds", @"powerbeats", @"beats",
    @"jabra", @"sony", @"bose", @"audio"
  ];

  for (AVAudioSessionPortDescription *input in availInputs) {
    NSString *portType = input.portType;
    NSString *portName = input.portName;
    NSString *portNameLowcase = input.portName.lowercaseString;

    if ([portType isEqualToString:AVAudioSessionPortBluetoothHFP]) {
      for (NSString *keyword in headphoneKeywords) {
        if ([portNameLowcase containsString:keyword.lowercaseString]) {
          [bluetoothDevices
              addObject:@{@"portName" : portName, @"portType" : portType}];
          break;
        }
      }
    }
  }

  NSError *error = nil;
  NSData *jsonData = [NSJSONSerialization dataWithJSONObject:bluetoothDevices
                                                     options:0
                                                       error:&error];
  if (error) {
    NSLog(@"Error serializing JSON: %@", error.localizedDescription);
    return nil;
  }
  NSString *jsonString = [[NSString alloc] initWithData:jsonData
                                               encoding:NSUTF8StringEncoding];
  return jsonString;
}
@end
