import 'package:flutter/material.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              // 뒤로 가기
              IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () => Navigator.pop(context),
              ),

              const SizedBox(height: 20),
              Center(
                child: Text(
                  '회원가입',
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

              // 이름 입력 필드
              Row(
                children: [
                  Expanded(child: _inputField('First Name', 'gildong')),
                  const SizedBox(width: 12),
                  Expanded(child: _inputField('Last Name', 'Hong')),
                ],
              ),
              const SizedBox(height: 16),

              // 이메일
              _inputField('E-mail', 'Enter your email'),
              const SizedBox(height: 16),

              // 비밀번호
              _inputField('Password', '*********'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'must contain 8 char.',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontFamily: 'Gabarito',
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 비밀번호 확인
              _inputField('Confirm Password', '*********'),
              const SizedBox(height: 40),

              // 회원가입 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: 계정 생성 로직
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF00B6DF),
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: StadiumBorder(),
                  ),
                  child: Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'Gabarito',
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),
              Image.network(
                'https://placehold.co/390x52',
                width: double.infinity,
                height: 52,
                fit: BoxFit.cover,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inputField(String label, String hintText) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontFamily: 'Gabarito',
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Color(0xFFE2E8F0), width: 1.5),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
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
        ),
      ],
    );
  }
}
