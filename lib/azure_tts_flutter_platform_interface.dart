import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'azure_tts_flutter_method_channel.dart';

typedef void StringResultHandler(String text);

abstract class AzureTtsFlutterPlatform extends PlatformInterface {
  /// Constructs a AzureTtsFlutterPlatform.
  AzureTtsFlutterPlatform() : super(token: _token);

  static final Object _token = Object();

  static AzureTtsFlutterPlatform _instance = MethodChannelAzureTtsFlutter();

  /// The default instance of [AzureTtsFlutterPlatform] to use.
  ///
  /// Defaults to [MethodChannelAzureTtsFlutter].
  static AzureTtsFlutterPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [AzureTtsFlutterPlatform] when
  /// they register themselves.
  static set instance(AzureTtsFlutterPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  void init(String key, String region, String lang) {
    throw UnimplementedError('init() has not been implemented.');
  }

  void startRecognize(String filePath) {
    throw UnimplementedError('startRecognize() has not been implemented.');
  }

  void stopRecognize() {
    throw UnimplementedError('stopRecognize() has not been implemented.');
  }

  void setRecognitionResultHandler(StringResultHandler handler) {
    throw UnimplementedError('startRecognize() has not been implemented.');
  }

  void setRecognizingHandler(StringResultHandler handler) {
    throw UnimplementedError('startRecognize() has not been implemented.');
  }

  void setSessionStoppedHandler(StringResultHandler handler) {
    throw UnimplementedError(
        'setSessionStoppedHandler() has not been implemented.');
  }
}
