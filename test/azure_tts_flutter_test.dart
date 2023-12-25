import 'package:flutter_test/flutter_test.dart';
import 'package:azure_tts_flutter/azure_tts_flutter.dart';
import 'package:azure_tts_flutter/azure_tts_flutter_platform_interface.dart';
import 'package:azure_tts_flutter/azure_tts_flutter_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockAzureTtsFlutterPlatform
    with MockPlatformInterfaceMixin
    implements AzureTtsFlutterPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final AzureTtsFlutterPlatform initialPlatform = AzureTtsFlutterPlatform.instance;

  test('$MethodChannelAzureTtsFlutter is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelAzureTtsFlutter>());
  });

  test('getPlatformVersion', () async {
    AzureTtsFlutter azureTtsFlutterPlugin = AzureTtsFlutter();
    MockAzureTtsFlutterPlatform fakePlatform = MockAzureTtsFlutterPlatform();
    AzureTtsFlutterPlatform.instance = fakePlatform;

    expect(await azureTtsFlutterPlugin.getPlatformVersion(), '42');
  });
}
