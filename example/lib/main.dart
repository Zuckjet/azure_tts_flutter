import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:azure_tts_flutter/azure_tts_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';
  final _azureTtsFlutterPlugin = AzureTtsFlutter();

  String _centerText = '';
  bool isRecognizing = false;

  String intermediateResult = '';
  String finalResult = '';

  @override
  void initState() {
    super.initState();
    initPlatformState();

    initAzure();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    // We also handle the message potentially returning null.
    try {
      platformVersion = await _azureTtsFlutterPlugin.getPlatformVersion() ??
          'Unknown platform version';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  Future<void> start() async {
    try {
      // await platform.invokeMethod('startRecognize');
      _azureTtsFlutterPlugin.startRecognize();
    } on PlatformException catch (e) {
      print(e.message);
    }
  }

  Future<void> stop() async {
    try {
      // await platform.invokeMethod('startRecognize');
      _centerText = '';
      finalResult = '';
      _azureTtsFlutterPlugin.stopRecognize();
    } on PlatformException catch (e) {
      print(e.message);
    }
  }

  Future platformCallHandler(MethodCall call) async {
    switch (call.method) {
      case "azure.onStartAvailable":
        print(call.arguments);
        break;
      case "azure.onRecognitionStopped":
        print(call.arguments);
        break;
      default:
        print("Error: method called not found");
    }
  }

  void initAzure() {
    String key = 'xxxx';
    String region = 'xxxxxx';
    String lang = 'zh-CN';
    _azureTtsFlutterPlugin.init(key, region, lang);

    // zuckjet code
    _azureTtsFlutterPlugin.setRecognitionResultHandler((text) {
      print('result handler handler 9999999999999');
      print(text);
      print(finalResult);
      finalResult += text;
      setState(() {
        _centerText = finalResult;
      });
    });

    _azureTtsFlutterPlugin.setRecognizingHandler((text) {
      print('ing ing ing ing ing 8888888888888');
      print(text);
      print(finalResult);
      setState(() {
        _centerText = finalResult + text;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('azure_tts_flutter example'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              Text(_centerText),
              Container(
                height: 60,
              ),
              ElevatedButton(
                onPressed: start,
                child: const Text('start recognize'),
              ),
              Container(
                height: 40,
              ),
              ElevatedButton(
                onPressed: stop,
                child: const Text('stop recognize'),
              ),
              Container(
                height: 80,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
