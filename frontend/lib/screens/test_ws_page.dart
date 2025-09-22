import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import '../services/exercise_ws.dart';

class TestWsPage extends StatefulWidget {
  final String userId;
  final String exercise; // 'pushup' 등
  final String wsUrl;
  const TestWsPage({
    super.key,
    required this.userId,
    required this.exercise,
    required this.wsUrl,
  });

  @override
  State<TestWsPage> createState() => _TestWsPageState();
}

class _TestWsPageState extends State<TestWsPage> {
  late ExerciseWsClient ws;
  Timer? _timer;
  String label = '-';
  double proba = 0.0;
  int count = 0;
  final rnd = Random();

  List<Map<String,double>> _fake17() {
    // [0,1] 범위의 중심 근처에 17개 포인트 생성
    return List.generate(17, (_) => {
      "x": 0.5 + (rnd.nextDouble()-0.5)*0.1,
      "y": 0.5 + (rnd.nextDouble()-0.5)*0.1,
      "score": 0.9,
    });
  }

  @override
  void initState() {
    super.initState();
    ws = ExerciseWsClient(widget.wsUrl);
    ws.start(widget.userId, widget.exercise);
    ws.stream?.listen((event) {
      try {
        final data = event is String ? jsonDecode(event) : event;
        if (data["type"] == "inference") {
          setState(() {
            label = data["label"];
            proba = (data["proba"] as num).toDouble();
            count = (data["count"] as num).toInt();
          });
        }
      } catch (_) {}
    });
  }

  void _startSend() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 125), (_) {
      ws.sendFrame(_fake17()); // ~8 FPS
    });
  }

  void _stopSend() {
    _timer?.cancel();
  }

  @override
  void dispose() {
    _timer?.cancel();
    ws.finish();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('WS Test - ${widget.exercise}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                ElevatedButton(onPressed: _startSend, child: const Text('Start Frames')),
                const SizedBox(width: 12),
                OutlinedButton(onPressed: _stopSend, child: const Text('Stop Frames')),
              ],
            ),
            const SizedBox(height: 16),
            Text('Label: $label'),
            Text('Proba: ${proba.toStringAsFixed(2)}'),
            Text('Count: $count'),
          ],
        ),
      ),
    );
  }
}
