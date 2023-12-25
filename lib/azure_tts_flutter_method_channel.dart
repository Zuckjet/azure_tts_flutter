import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'azure_tts_flutter_platform_interface.dart';

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
  }

  @override
  void startRecognize() {
    methodChannel.invokeMethod('startRecognize', {
      'key': _key,
      'region': _region,
      'lang': _lang,
    });
  }
}
