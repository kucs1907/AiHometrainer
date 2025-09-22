// lib/screens/onboarding_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // kDebugMode, debugPrint
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  Future<void> _handleKakaoLogin(BuildContext context) async {
    try {
      // // ===== DEBUG-ONLY: 강제 재인증(웹 계정 로그인 + 아이디/비번 입력) + 타임아웃/로그 — START =====
      if (kDebugMode) {
        try {
          await UserApi.instance.logout(); // 기존 토큰 정리(선택)
        } catch (_) {}

        debugPrint('[Kakao] Reauth start: loginWithKakaoAccount(Prompt.login)');

        // 콜백이 안 오면 20초 후 타임아웃 → 원인 파악에 도움
        final token = await UserApi.instance
            .loginWithKakaoAccount(prompts: [Prompt.login])
            .timeout(const Duration(seconds: 20));

        debugPrint('[Kakao] token received: ${token.accessToken.substring(0, 8)}...');

        await UserApi.instance.accessTokenInfo();

        if (!context.mounted) return;
        debugPrint('[Kakao] navigate -> /home');
        Navigator.pushReplacementNamed(context, '/home');
        return; // 디버그 경로 종료
      }
      // // ===== DEBUG-ONLY: 강제 재인증(웹 계정 로그인 + 아이디/비번 입력) + 타임아웃/로그 — END =====

      // 릴리즈/일반 경로: 카카오톡 설치 시 톡 로그인, 아니면 계정 로그인
      final installed = await isKakaoTalkInstalled();
      final token = installed
          ? await UserApi.instance.loginWithKakaoTalk()
          : await UserApi.instance.loginWithKakaoAccount();

      await UserApi.instance.accessTokenInfo();

      if (!context.mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } on TimeoutException {
      if (!context.mounted) return;
      debugPrint('[Kakao] Timeout waiting for auth callback');
      showDialog(
        context: context,
        builder: (_) => const AlertDialog(
          title: Text('로그인 콜백이 오지 않아요'),
          content: Text(
            '다음을 확인해주세요.\n'
            '• Kakao 콘솔 Android 플랫폼의 패키지명(applicationId) 일치\n'
            '• 키 해시 정확히 등록\n'
            '• (중요) 네이티브 Kakao SDK 중복 의존성 제거\n'
            '• AndroidManifest에서 taskAffinity 미설정\n',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      debugPrint('[Kakao] login error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('카카오 로그인 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      // ===== DEBUG-ONLY: Kakao test logout (쉽게 제거 가능) — START =====
      appBar: AppBar(
        title: const Text('AI Hometrainer'),
        actions: [
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: '테스트 로그아웃',
              onPressed: () async {
                try {
                  await UserApi.instance.logout(); // 토큰만 삭제
                  // 더 강하게 초기화하려면: await UserApi.instance.unlink(); // 앱 연결 해제(다음 로그인 시 재동의)
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('테스트용 로그아웃 완료')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('로그아웃 실패: $e')),
                    );
                  }
                }
              },
            ),
        ],
      ),
      // ===== DEBUG-ONLY: Kakao test logout (쉽게 제거 가능) — END =====

      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'AI Hometrainer',
                  style: TextStyle(
                    color: Color(0xFF161626),
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '집에서 똑똑하게 운동 시작하기',
                  style: TextStyle(
                    color: Color(0xFF79797F),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),

              const SizedBox(height: 32),
              Expanded(
                child: Center(
                  child: Image.asset(
                    'assets/images/dumbbell.png',
                    width: size.width * 0.55,
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFEE500), // 카카오 컬러
                    foregroundColor: Colors.black87,
                    minimumSize: const Size(double.infinity, 52),
                    shape: const StadiumBorder(), // 둥근 모서리
                    elevation: 0,
                  ),
                  onPressed: () => _handleKakaoLogin(context),
                  child: const Text(
                    '카카오로 시작하기',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),
            ],
          ),
        ),
      ),
    );
  }
}
