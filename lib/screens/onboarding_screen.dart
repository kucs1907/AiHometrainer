import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  Future<void> _handleKakaoLogin(BuildContext context) async {
    try {
      // 카카오톡 앱 설치 여부 확인
      bool isInstalled = await isKakaoTalkInstalled();

      // 로그인 진행
      OAuthToken token = isInstalled
          ? await UserApi.instance.loginWithKakaoTalk()
          : await UserApi.instance.loginWithKakaoAccount();

      // 사용자 정보 가져오기
      User user = await UserApi.instance.me();

      print('✅ 로그인 성공');
      print('🧑 사용자 ID: ${user.id}');
      print('📝 닉네임: ${user.kakaoAccount?.profile?.nickname}');

      // 로그인 성공 후 홈으로 이동
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      print('❌ 카카오 로그인 실패: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('카카오 로그인에 실패했습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned(
            top: 18,
            left: 16,
            child: Text(
              '9:41',
              style: TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // 중앙 이미지
          Positioned(
            top: 100,
            left: (screenWidth - 220) / 2,
            child: Image.asset(
              'assets/images/dumbbell.png',
              width: 220,
              height: 220,
              fit: BoxFit.contain,
            ),
          ),

          // 하단 버튼
          Positioned(
            left: 16,
            right: 16,
            bottom: 80,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/register');
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Color(0xFF1E293B), width: 2),
                      shape: StadiumBorder(),
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Register',
                      style: TextStyle(
                        color: Color(0xFF1E293B),
                        fontSize: 14,
                        fontFamily: 'Gabarito',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/login');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF00B6DF),
                      shape: StadiumBorder(),
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Login',
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'Gabarito',
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 하단 카카오 배너 (터치 시 로그인)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: GestureDetector(
              onTap: () => _handleKakaoLogin(context),
              child: Image.asset(
                'assets/images/kakao_banner.png',
                height: 52,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
