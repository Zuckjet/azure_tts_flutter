import 'dart:async';
import 'package:flutter/material.dart';
import 'package:azure_tts_flutter/azure_tts_flutter.dart';
import 'package:azure_tts_flutter/recording_interrupt_event.dart';

import 'package:path_provider/path_provider.dart';
import 'dart:io';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isRecording = false;
  String _recognizedText = '';
  String _lastError = '';
  String _filePath = '';

  StreamSubscription<RecordingInterruptionEvent>? _interruptionSubscription;

  final azureTtsFlutterPlugin = AzureTtsFlutter();

  @override
  void initState() {
    super.initState();
    azureTtsFlutterPlugin.init();
    _initFilePath();

    // Listen for recording interruptions
    _interruptionSubscription = azureTtsFlutterPlugin.onRecordingInterrupted
        .listen(_handleInterruption);
  }

  Future<void> _initFilePath() async {
    await _requestPermission();
    final directory = await getTemporaryDirectory();
    _filePath = '${directory.path}/recording.caf';
  }

  Future<void> _requestPermission() async {
    // await Permission.microphone.request();
    // await Permission.storage.request();
  }

  void _handleInterruption(RecordingInterruptionEvent event) {
    var reason = event.reason.toString().split('.').last;
    if (event.reason == RecordingInterruptionReason.startPanic ||
        event.reason == RecordingInterruptionReason.stopPanic) {
      azureTtsFlutterPlugin.stopRecognize();
    }

    setState(() {
      _isRecording = false;
      _lastError = '$reason - ${event.message}';
    });
    // zhu
    print(_lastError);
    //zhu
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await azureTtsFlutterPlugin.stopRecognize();
      setState(() {
        _isRecording = false;
      });
    } else {
      setState(() {
        _lastError = '';
        _recognizedText = '';
      });

      final String key = "";
      final String region = "";

      final bool success = await azureTtsFlutterPlugin.startRecognize(
          key, region, "zh-CN", _filePath);

      setState(() {
        _isRecording = success;
      });
    }
  }

  @override
  void dispose() {
    _interruptionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Azure TTS Flutter Example'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(
                onPressed: _toggleRecording,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isRecording ? Colors.red : Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                ),
                child: Text(
                  _isRecording ? 'Stop Recording' : 'Start Recording',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(height: 20),
              if (_recognizedText.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                  child: Text(
                    _recognizedText,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              const SizedBox(height: 20),
              if (_lastError.isNotEmpty)
                Text(
                  _lastError,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
