import 'azure_tts_flutter_platform_interface.dart';

class AzureTtsFlutter {
  Future<String?> getPlatformVersion() {
    return AzureTtsFlutterPlatform.instance.getPlatformVersion();
  }

  void init(String key, String region, String lang) {
    AzureTtsFlutterPlatform.instance.init(key, region, lang);
  }

  void startRecognize(String filePath) {
    AzureTtsFlutterPlatform.instance.startRecognize(filePath);
  }

  void stopRecognize() {
    AzureTtsFlutterPlatform.instance.stopRecognize();
  }

  void setRecognitionResultHandler(StringResultHandler handler) {
    AzureTtsFlutterPlatform.instance.setRecognitionResultHandler(handler);
  }

  void setRecognizingHandler(StringResultHandler handler) {
    AzureTtsFlutterPlatform.instance.setRecognizingHandler(handler);
  }

  void setSessionStoppedHandler(StringResultHandler handler) {
    AzureTtsFlutterPlatform.instance.setSessionStoppedHandler(handler);
  }
}
