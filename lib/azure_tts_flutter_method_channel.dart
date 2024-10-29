import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'azure_tts_flutter_platform_interface.dart';

typedef void StringResultHandler(String text);

/// An implementation of [AzureTtsFlutterPlatform] that uses method channels.
class MethodChannelAzureTtsFlutter extends AzureTtsFlutterPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('azure_tts_flutter');

  @override
  Future<String?> getPlatformVersion() async {
    final version =
        await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  // zuckjet online demo
  static String? _key;
  static String? _region;
  static String? _lang;

  @override
  void init(String key, String region, String lang) {
    _key = key;
    _region = region;
    _lang = lang;

    // zuckjet
    methodChannel.setMethodCallHandler(_platformCallHandler);
  }

  // test zuckjet
  StringResultHandler? exceptionHandler;
  StringResultHandler? recognitionResultHandler;
  StringResultHandler? recognizingHandler;
  StringResultHandler? sessionStoppedHandler;
  StringResultHandler? assessmentResultHandler;
  VoidCallback? recognitionStartedHandler;
  VoidCallback? startRecognitionHandler;
  VoidCallback? recognitionStoppedHandler;
  // VoidCallback? sessionStoppedHandler;

  @override
  void setRecognitionResultHandler(StringResultHandler handler) =>
      recognitionResultHandler = handler;

  @override
  void setRecognizingHandler(StringResultHandler handler) =>
      recognizingHandler = handler;

  @override
  void setSessionStoppedHandler(StringResultHandler handler) =>
      sessionStoppedHandler = handler;

  Future _platformCallHandler(MethodCall call) async {
    switch (call.method) {
      case "speech.onRecognitionStarted":
        recognitionStartedHandler!();
        break;
      case "speech.onResult":
        recognitionResultHandler!(call.arguments);
        break;
      case "speech.onSessionStopped":
        sessionStoppedHandler!(call.arguments);
        break;
      case "speech.onRecognizing":
        recognizingHandler!(call.arguments);
        break;
      case "speech.onAssessmentResult":
        assessmentResultHandler!(call.arguments);
        break;
      case "speech.onStartAvailable":
        startRecognitionHandler!();
        break;
      case "speech.onRecognitionStopped":
        recognitionStoppedHandler!();
        break;
      case "speech.onException":
        exceptionHandler!(call.arguments);
        break;
      default:
        print("Error: method called not found");
    }
  }

  @override
  void startRecognize(String filePath) {
    methodChannel.invokeMethod('startRecognize', {
      'key': _key,
      'region': _region,
      'lang': _lang,
      'filePath': filePath,
    });
  }

  @override
  void stopRecognize() {
    methodChannel.invokeMethod('stopRecognize');
  }
}
