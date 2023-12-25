import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:azure_tts_flutter/azure_tts_flutter_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelAzureTtsFlutter platform = MethodChannelAzureTtsFlutter();
  const MethodChannel channel = MethodChannel('azure_tts_flutter');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return '42';
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
