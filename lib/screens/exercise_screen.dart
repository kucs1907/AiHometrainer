import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:async';

class ExerciseScreen extends StatefulWidget {
  final List<String> selectedExercises;
  const ExerciseScreen({super.key, required this.selectedExercises});

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen>
    with SingleTickerProviderStateMixin {
  late CameraController _controller;
  bool _isCameraInitialized = false;

  int _count = 0;
  bool _isExercising = false;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeCamera();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front);

    _controller = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _controller.initialize();
    setState(() {
      _isCameraInitialized = true;
    });
  }

  void _startExercise() {
    setState(() {
      _isExercising = true;
    });

    // 예시: 서버에서 메시지 수신 시마다 count 증가
    Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!_isExercising) {
        timer.cancel();
      } else {
        _incrementCount();
      }
    });
  }

  void _stopExercise() {
    setState(() {
      _isExercising = false;
    });
  }

  void _incrementCount() {
    setState(() {
      _count++;
    });
    _animationController.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isCameraInitialized
          ? Stack(
        children: [
          CameraPreview(_controller),
          Positioned(
            top: 60,
            left: 0,
            right: 0,
            child: Center(
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    '횟수: $_count',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 40,
            right: 40,
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: _isExercising ? null : _startExercise,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                  child: const Text('운동 시작'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _isExercising ? _stopExercise : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                  child: const Text('운동 종료'),
                ),
              ],
            ),
          ),
        ],
      )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
