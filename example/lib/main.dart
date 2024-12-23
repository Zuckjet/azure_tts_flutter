import 'dart:convert';

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'package:flutter/services.dart';
import 'package:azure_tts_flutter/azure_tts_flutter.dart';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';

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
  String filePaths = '';

  @override
  void initState() {
    super.initState();
    initPlatformState();
    initAzure();
    // print(datas);

    // test();
  }

  void test() async {
    if (!File(filePaths).existsSync()) {
      print('file not exist');
    } else {
      print('file exist');
    }

    await Future.delayed(const Duration(seconds: 5));

    final player = AudioPlayer();
    player.setVolume(50000);
    await player.play(DeviceFileSource(filePaths));
  }

  Future<String> getPath(String prefix, String suffix) async {
    final dir = await getApplicationDocumentsDirectory();
    final fileName =
        '${prefix}_${DateTime.now().millisecondsSinceEpoch}.$suffix';
    return p.join(
      dir.path,
      fileName,
    );
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
    finalResult = '';
    setState(() {
      _centerText = '';
    });

    try {
      // await platform.invokeMethod('startRecognize');

      final filePath = await getPath('record_note', 'wav');
      filePaths = filePath;
      _azureTtsFlutterPlugin.startRecognize(filePath);
    } on PlatformException catch (e) {
      print(e.message);
    }

    await Future.delayed(const Duration(seconds: 3));
    String? a;
    try {
      a = await _azureTtsFlutterPlugin.getBluetoothDevices();
    } catch (e) {
      // ...
    }

    if (a != null) {
      final List<dynamic> jsonArray = jsonDecode(a);
      var b = jsonArray.map((map) => Map<String, String>.from(map)).toList();

      for (var person in b) {
        print('name: ${person['portName']}, type: ${person['portType']}');
      }

      if (b.isNotEmpty) {
        print('b is not empty');
      }
    }
  }

  Future<void> stop() async {
    try {
      // await platform.invokeMethod('startRecognize');
      print('change your name information online demoooooo');
      _azureTtsFlutterPlugin.stopRecognize();
    } on PlatformException catch (e) {
      print(e.message);
    }
    // test();
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
    String key = 'xx';
    String region = 'xx';
    String lang = 'zh-CN';
    _azureTtsFlutterPlugin.init(key, region, lang);

    // zuckjet code
    _azureTtsFlutterPlugin.setRecognitionResultHandler((text) {
      setState(() {
        _centerText = finalResult;
      });
    });

    _azureTtsFlutterPlugin.setRecognizingHandler((text) {
      setState(() {
        _centerText = finalResult + text;
      });
    });

    _azureTtsFlutterPlugin.setSessionStoppedHandler((text) {
      print(text);
      print('log sesstion stop event');
    });

    _azureTtsFlutterPlugin.setRecognitionFileResultHandler((text) {
      print('file result: $text');
    });

    _azureTtsFlutterPlugin.setRecognitionFileStopHandler((text) {
      print('file stop: $text');
    });
  }

  recognizeWithFile() async {
    _azureTtsFlutterPlugin.startRecognizeWithFile('filepath');
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
              ElevatedButton(
                onPressed: recognizeWithFile,
                child: const Text('file'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
