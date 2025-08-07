import 'dart:convert';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart'; // 날짜 포맷용

class LiveFeedbackScreen extends StatefulWidget {
  final List<String> selectedExercises;

  const LiveFeedbackScreen({super.key, required this.selectedExercises});

  @override
  State<LiveFeedbackScreen> createState() => _LiveFeedbackScreenState();
}

class _LiveFeedbackScreenState extends State<LiveFeedbackScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  WebSocketChannel? _channel;
  String feedbackMessage = "서버로부터 피드백 대기 중...";
  int count = 0;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  int currentExerciseIndex = 0;

  @override
  void initState() {
    super.initState();
    _initCamera();
    //_connectWebSocket(); // 웹소켓 시도여부

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      lowerBound: 1.0,
      upperBound: 1.5,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }


  Future<void> markTodayAsExercised() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await prefs.setString('last_exercise_date', today);
  }




  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
    );

    _cameraController = CameraController(frontCamera, ResolutionPreset.medium);
    await _cameraController!.initialize();

    setState(() {});
    _sendSimulatedDataLoop();
  }

  void _connectWebSocket() {
    _channel = WebSocketChannel.connect(
      Uri.parse('ws://your_server_ip:port'), // 실제 서버 주소로 교체
    );

    _channel!.stream.listen((message) {
      setState(() {
        feedbackMessage = message;

        if (message.contains("correct")) {
          count++;
          _animationController.forward(from: 0.0);
        }
      });
    });
  }

  void _sendSimulatedDataLoop() async {
    while (mounted && _channel != null) {
      await Future.delayed(const Duration(seconds: 2));
      final simulated = {
        "x": Random().nextDouble() * 100,
        "y": Random().nextDouble() * 100,
        "angle": Random().nextDouble() * 180,
      };
      _channel!.sink.add(jsonEncode(simulated));
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _channel?.sink.close();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentExercise =
    widget.selectedExercises[currentExerciseIndex % widget.selectedExercises.length];

    return Scaffold(
      body: Stack(
        children: [
          _cameraController != null && _cameraController!.value.isInitialized
              ? CameraPreview(_cameraController!)
              : const Center(child: CircularProgressIndicator()),

          // 🔠 현재 운동 이름
          Positioned(
            top: 40,
            left: 20,
            child: Text(
              currentExercise,
              style: const TextStyle(
                fontSize: 20,
                color: Colors.white,
                fontWeight: FontWeight.bold,
                backgroundColor: Colors.black54,
              ),
            ),
          ),

          // 🔢 카운트 애니메이션
          Positioned(
            top: 80,
            left: 0,
            right: 0,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Center(
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "$count 회",
                    style: const TextStyle(
                      fontSize: 32,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 💬 서버 피드백
          Positioned(
            bottom: 140,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                feedbackMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ),

          // 🛑 종료 버튼
          Positioned(
            bottom: 50,
            left: MediaQuery.of(context).size.width / 2 - 60,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
              onPressed: ()  async {
                await markTodayAsExercised(); // ✅ 운동 날짜 저장
                Navigator.pop(context);
              },
              child: const Text("운동 종료", style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
