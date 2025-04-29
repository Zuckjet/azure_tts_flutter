import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'azure_tts_flutter_platform_interface.dart';
import 'recording_interrupt_event.dart';

typedef void StringResultHandler(String text);

/// An implementation of [AzureTtsFlutterPlatform] that uses method channels.
class MethodChannelAzureTtsFlutter extends AzureTtsFlutterPlatform {
  /// The method channel used to interact with the native platform.
  // @visibleForTesting
  // final _channel = const MethodChannel('azure_tts_flutter');
  final MethodChannel _channel = const MethodChannel('azure_tts_flutter');
  final EventChannel _eventChannel =
      const EventChannel('azure_tts_flutter_events');

  Stream<RecordingInterruptionEvent>? _recordingInterruptionStream;

  @override
  Stream<RecordingInterruptionEvent> get onRecordingInterrupted {
    _recordingInterruptionStream ??=
        _eventChannel.receiveBroadcastStream().where((event) {
      return event is Map && event['event'] == 'recording_interrupted';
    }).map((event) {
      return RecordingInterruptionEvent.fromMap(event);
    });
    return _recordingInterruptionStream!;
  }

  @override
  void init(String key, String region, String lang) {
    _channel.setMethodCallHandler(_platformCallHandler);
  }

  // test
  StringResultHandler? exceptionHandler;
  StringResultHandler? recognitionResultHandler;
  StringResultHandler? recognizingHandler;
  StringResultHandler? sessionStoppedHandler;
  StringResultHandler? assessmentResultHandler;
  VoidCallback? recognitionStartedHandler;
  VoidCallback? startRecognitionHandler;
  VoidCallback? recognitionStoppedHandler;
  // VoidCallback? sessionStoppedHandler;
  StringResultHandler? recognitionFileResultHandler;
  StringResultHandler? recognitionFileStopHandler;

  @override
  Future<String?> getPlatformVersion() async {
    final version = await _channel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<String?> getBluetoothDevices() async {
    final devices = await _channel.invokeMethod<String>('getBluetoothDevices');
    return devices;
  }

  @override
  void setRecognitionResultHandler(StringResultHandler handler) =>
      recognitionResultHandler = handler;

  @override
  void setRecognizingHandler(StringResultHandler handler) =>
      recognizingHandler = handler;

  @override
  void setSessionStoppedHandler(StringResultHandler handler) =>
      sessionStoppedHandler = handler;

  @override
  void setRecognitionFileResultHandler(StringResultHandler handler) =>
      recognitionFileResultHandler = handler;

  @override
  setRecognitionFileStopHandler(StringResultHandler handler) =>
      recognitionFileStopHandler = handler;

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
      case "recognizeFile.onResult":
        recognitionFileResultHandler!(call.arguments);
        break;
      case "recognizeFile.onStop":
        recognitionFileStopHandler!(call.arguments);
        break;
      case "speech.onException":
        exceptionHandler!(call.arguments);
        break;
      default:
        print("Error: method called not found");
    }
  }

  @override
  Future<bool> startRecognize(
      String key, String region, String lang, String filePath) async {
    final result = await _channel.invokeMethod<bool>('startRecognize',
        {'key': key, 'region': region, 'lang': lang, 'filePath': filePath});
    return result ?? false;
  }

  @override
  Future<bool> stopRecognize() async {
    final result = await _channel.invokeMethod('stopRecognize');
    return result ?? false;
  }

  @override
  Future<bool> startRecognizeWithFile(
      String key, String region, String lang, String filePath) async {
    final result = await _channel.invokeMethod('startRecognizeWithFile', {
      'key': key,
      'region': region,
      'lang': lang,
      'filePath': filePath,
    });
    return result ?? false;
  }
}
