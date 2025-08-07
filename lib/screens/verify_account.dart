import 'package:flutter/material.dart';

class VerifyAccountScreen extends StatelessWidget {
  const VerifyAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          '계정 확인',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ListView(
          children: [
            const SizedBox(height: 40),
            _infoText(),
            const SizedBox(height: 32),
            _inputField(),
            const SizedBox(height: 32),
            _resendSection(),
            const SizedBox(height: 100),
            _verifyButton(context),
          ],
        ),
      ),
    );
  }

  Widget _infoText() {
    return Column(
      children: [
        Text.rich(
          TextSpan(
            text: 'Code has been sent to ',
            style: TextStyle(
              color: Color(0xFF475569),
              fontSize: 14,
              fontFamily: 'Gabarito',
            ),
            children: [
              TextSpan(
                text: 'gildongHong@gmail.com',
                style: TextStyle(
                  color: Color(0xFF1E293B),
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextSpan(text: '.'),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Enter the code to verify your account.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF475569),
            fontFamily: 'Gabarito',
          ),
        ),
      ],
    );
  }

  Widget _inputField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Enter Code',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF1E293B),
            fontFamily: 'Gabarito',
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(color: Color(0xFFE2E8F0), width: 1.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const TextField(
            decoration: InputDecoration(
              hintText: '4 Digit Code',
              border: InputBorder.none,
              hintStyle: TextStyle(
                fontSize: 14,
                color: Color(0xFF94A3B8),
                fontFamily: 'Gabarito',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _resendSection() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text(
              '코드를 못받았나요?',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF475569),
                fontFamily: 'Gabarito',
              ),
            ),
            SizedBox(width: 4),
            Text(
              'Resend Code',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w500,
                fontFamily: 'Gabarito',
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Resend code in 00:59',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF475569),
            fontFamily: 'Gabarito',
          ),
        ),
      ],
    );
  }

  Widget _verifyButton(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        // TODO: 인증 처리 후 다음 화면 이동
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Color(0xFF00B6DF),
        shape: StadiumBorder(),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child: const Text(
        'Verify Account',
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontFamily: 'Gabarito',
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
