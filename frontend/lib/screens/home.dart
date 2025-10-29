// lib/screens/home.dart
import 'package:flutter/material.dart';
import 'select_exercise.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // ---- 튜닝 포인트 ----
    final double topBarTop = 12;                 // 상단 타이틀/설정 높이
    final double horizontalPad = 20;             // 좌우 패딩
    final double historyTop = size.height * 0.16; // 운동 기록 버튼 Y
    final double historyWidth = size.width * 0.74;// 운동 기록 버튼 너비
    final double historyHeight = 60;             // 운동 기록 버튼 높이
    final double startBtnSize = size.width * 0.80;// 시작 버튼 크기

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Stack(
          children: [
            // ✅ 상단 바: 좌측 타이틀 + 우측 설정 (같은 높이)
            Positioned(
              top: topBarTop,
              left: horizontalPad,
              right: horizontalPad,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'AI Hometrainer',
                    style: TextStyle(
                      color: Color(0xFF161626),
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/settings'),
                    child: const Icon(Icons.settings, size: 34, color: Colors.black87),
                  ),
                ],
              ),
            ),

            // ✅ 운동 기록: 중앙 정렬(가로) + 아웃라인 스타일(검정 테두리/흰 배경/검정 글씨)
            Positioned(
              top: historyTop,
              left: (size.width - historyWidth) / 2,
              child: SizedBox(
                width: historyWidth,
                height: historyHeight,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/history'),
                  icon: const Icon(Icons.bar_chart_rounded, size: 22),
                  label: const Text(
                    '운동 기록',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black,             // 아이콘/텍스트
                    backgroundColor: Colors.white,              // 내부 흰색
                    side: const BorderSide(color: Colors.black, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),

            // ✅ 운동 시작
            Align(
              alignment: const Alignment(0, 0.60),
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SelectExerciseScreen()),
                ),
                child: Image.asset(
                  'assets/images/start_exercise.png',
                  width: startBtnSize,
                  height: startBtnSize,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
