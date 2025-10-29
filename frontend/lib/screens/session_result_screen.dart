// lib/screens/session_result_screen.dart
import 'package:flutter/material.dart';

class SessionResultArgs {
  final String exerciseKo;
  final String exerciseEn;
  final int reps;
  final double accuracy; // 0.0 ~ 1.0
  final int sessionId;
  final String feedback; // 요약 피드백

  SessionResultArgs({
    required this.exerciseKo,
    required this.exerciseEn,
    required this.reps,
    required this.accuracy,
    required this.sessionId,
    required this.feedback,
  });
}

class SessionResultScreen extends StatelessWidget {
  const SessionResultScreen({super.key});

  String _fmtPct(double v) => (v * 100).toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)!.settings.arguments as SessionResultArgs;

    // ✅ 정확도 95% 이상일 때 고정 문구로 대체
    const greatMsg = "운동 총평\n• 전반적으로 안정적인 자세였어요. 지금 리듬을 유지해봅시다!";
    String normalizedFeedback = (args.feedback.isNotEmpty)
        ? args.feedback.replaceFirst(RegExp(r'^세션 총평'), '운동 총평') // 레거시 치환
        : "운동 총평\n• 전반적으로 안정적인 자세였어요. 지금 리듬을 유지해봅시다!";

    final String feedbackToShow =
        (args.accuracy >= 0.95) ? greatMsg : normalizedFeedback;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('운동 결과', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),

      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 48,
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.of(context)
                      .pushNamedAndRemoveUntil('/home', (r) => false),
                  child: const Text('홈으로',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 48,
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.black, width: 2),
                    foregroundColor: Colors.black,
                    shape: const StadiumBorder(),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('다시 하기',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${args.exerciseKo} (${args.exerciseEn})',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),

            const SizedBox(height: 20),

            Center(
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.black, width: 3),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '총 횟수',
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${args.reps}',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 64,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _Chip(text: '정확도 ${_fmtPct(args.accuracy)}%'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ✅ 피드백 카드
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black12, width: 1.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                feedbackToShow,
                style: const TextStyle(fontSize: 16, color: Colors.black87, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  const _Chip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black),
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
