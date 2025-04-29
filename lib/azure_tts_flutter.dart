import 'azure_tts_flutter_platform_interface.dart';

class AzureTtsFlutter {
  get onRecordingInterrupted =>
      AzureTtsFlutterPlatform.instance.onRecordingInterrupted;

  Future<String?> getPlatformVersion() {
    return AzureTtsFlutterPlatform.instance.getPlatformVersion();
  }

  Future<String?> getBluetoothDevices() {
    return AzureTtsFlutterPlatform.instance.getBluetoothDevices();
  }

  void init(String key, String region, String lang) {
    AzureTtsFlutterPlatform.instance.init(key, region, lang);
  }

  Future<bool> startRecognize(
      String key, String region, String lang, String filePath) async {
    return await AzureTtsFlutterPlatform.instance
        .startRecognize(key, region, lang, filePath);
  }

  Future<bool> startRecognizeWithFile(
      String key, String region, String lang, String filePath) async {
    return await AzureTtsFlutterPlatform.instance
        .startRecognizeWithFile(key, region, lang, filePath);
  }

  Future<bool> stopRecognize() async {
    return await AzureTtsFlutterPlatform.instance.stopRecognize();
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

  void setRecognitionFileResultHandler(StringResultHandler handler) {
    AzureTtsFlutterPlatform.instance.setRecognitionFileResultHandler(handler);
  }

  void setRecognitionFileStopHandler(StringResultHandler handler) {
    AzureTtsFlutterPlatform.instance.setRecognitionFileStopHandler(handler);
  }
}
