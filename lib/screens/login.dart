import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),
                // 뒤로가기 버튼 (아이콘은 placeholder)
                IconButton(
                  icon: Icon(Icons.arrow_back_ios_new_rounded),
                  onPressed: () => Navigator.pop(context),
                ),

                const SizedBox(height: 20),
                Center(
                  child: Text(
                    '로그인',
                    style: TextStyle(
                      fontSize: 30,
                      fontFamily: 'Gabarito',
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                      letterSpacing: -0.15,
                    ),
                  ),
                ),

                const SizedBox(height: 40),
                // 이메일 입력 필드
                Text(
                  'E-mail',
                  style: _labelStyle(),
                ),
                const SizedBox(height: 6),
                _textField(hintText: 'Enter your email'),

                const SizedBox(height: 20),
                // 비밀번호 입력 필드
                Text(
                  'Password',
                  style: _labelStyle(),
                ),
                const SizedBox(height: 6),
                _textField(hintText: 'Enter your password', obscureText: true),

                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {}, // TODO: 비밀번호 찾기 페이지 연결
                    child: Text(
                      'Forgot Password?',
                      style: TextStyle(
                        color: Color(0xFF3C9AFB),
                        fontFamily: 'Gabarito',
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                // 로그인 버튼
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/home'); // 임시 연결
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF00B6DF),
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: StadiumBorder(),
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

                const SizedBox(height: 40),
                Center(
                  child: Text(
                    'or login with',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontFamily: 'Gabarito',
                      fontSize: 14,
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // 하단 배너
                Image.asset(
                  'assets/images/kakao_banner.png',
                  width: double.infinity,
                  height: 52,
                  fit: BoxFit.cover,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _textField({required String hintText, bool obscureText = false}) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Color(0xFFE2E8F0), width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        obscureText: obscureText,
        decoration: InputDecoration(
          hintText: hintText,
          border: InputBorder.none,
          hintStyle: TextStyle(
            color: Color(0xFF94A3B8),
            fontFamily: 'Gabarito',
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  TextStyle _labelStyle() {
    return TextStyle(
      color: Color(0xFF1E293B),
      fontFamily: 'Gabarito',
      fontSize: 14,
      fontWeight: FontWeight.w400,
    );
  }
}
