import 'package:flutter/services.dart';

class AzureTtsFlutter {
  static const MethodChannel _channel =
      const MethodChannel('azure_tts_flutter');

  static String? _key;
  static String? _region;
  static String? _lang;

  static void init(String key, String region, String lang) {
    _key = key;
    _region = region;
    _lang = lang;
  }

  static void startRecognize() {
    _channel.invokeMethod('startRecognize', {
      'key': _key,
      'region': _region,
      'lang': _lang,
    });
  }
}
