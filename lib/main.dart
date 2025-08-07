import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import 'screens/onboarding_screen.dart';
import 'screens/login.dart';
import 'screens/home.dart';
import 'screens/select_exercise.dart';
import 'screens/exercisehistory_screen.dart';
import 'screens/live_feedback_screen.dart';
import 'screens/settings.dart'; // settings.dart로 경로/이름 맞추세요!

import 'screens/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  KakaoSdk.init(nativeAppKey: '26a7ded3a7a8401698e45b4688ea24c7');
  await NotificationService.init(); // 알림 서비스 초기화!!
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AI Hometrainer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const OnboardingScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/select_exercise': (context) => const SelectExerciseScreen(),
        // '/history': (context) => ExerciseHistoryScreen(),
        '/history': (context) => const ExerciseHistoryScreen(userId: 1), // 테스트용 하드코딩
        //'/live_feedback': (context) => const LiveFeedbackScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}
