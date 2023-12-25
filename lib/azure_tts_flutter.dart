import 'azure_tts_flutter_platform_interface.dart';

class AzureTtsFlutter {
  Future<String?> getPlatformVersion() {
    return AzureTtsFlutterPlatform.instance.getPlatformVersion();
  }

  void init(String key, String region, String lang) {
    AzureTtsFlutterPlatform.instance.init(key, region, lang);
  }

  void startRecognize() {
    AzureTtsFlutterPlatform.instance.startRecognize();
  }
}
