// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

// FCM + 설정 API 연동
import 'services/push_service.dart';

// Screens
import 'screens/onboarding_screen.dart';
import 'screens/home.dart';
import 'screens/select_exercise.dart';
import 'screens/exercisehistory_screen.dart';
import 'screens/live_feedback_screen.dart';
import 'screens/settings.dart';

/// 백그라운드 FCM 핸들러 (앱이 종료/백그라운드일 때 수신)
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // 필요 시 로깅/처리
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) Firebase 초기화
  await Firebase.initializeApp();

  // 2) FCM 백그라운드 메시지 핸들러 등록
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 3) Kakao SDK 초기화
  KakaoSdk.init(nativeAppKey: '26a7ded3a7a8401698e45b4688ea24c7');

  // 4) 푸시 초기화 (토큰 획득 + 포그라운드 수신 리스너)
  await PushService.init();

  // 5) 서버/유저 설정
  PushService.configureServer("http://192.168.219.105:8000");
  PushService.configureUser("1"); // TODO: 로그인된 실제 사용자 ID로 교체

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
        '/home': (context) => const HomeScreen(),
        '/select_exercise': (context) => const SelectExerciseScreen(),

        // '/history': (context) => const ExerciseHistoryScreen(userId: 1), // 테스트용
        '/history': (context) {
          final userId = ModalRoute.of(context)!.settings.arguments as int;
          return ExerciseHistoryScreen(userId: userId);
        },

        // ✅ arguments → List<String>로 안전 변환 후 주입
        '/live_feedback': (context) {
          final args = ModalRoute.of(context)!.settings.arguments;
          if (args == null) {
            return const _MissingArgsScreen(
              routeName: '/live_feedback',
              expected: 'List<String> selectedExercises',
            );
          }

          // 허용: List<String> 또는 List<dynamic> (문자열로 변환)
          late final List<String> selectedExercises;
          if (args is List<String>) {
            selectedExercises = args;
          } else if (args is List) {
            try {
              selectedExercises = args.map((e) => e.toString()).toList();
            } catch (_) {
              return const _BadArgsScreen(
                routeName: '/live_feedback',
                expected: 'List<String>',
              );
            }
          } else {
            return const _BadArgsScreen(
              routeName: '/live_feedback',
              expected: 'List<String>',
            );
          }

          return LiveFeedbackScreen(selectedExercises: selectedExercises);
        },

        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}

/// 라우트 인자 누락 안내
class _MissingArgsScreen extends StatelessWidget {
  final String routeName;
  final String expected;
  const _MissingArgsScreen({super.key, required this.routeName, required this.expected});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("$routeName 인자 누락")),
      body: Center(child: Text("이 화면으로 이동하려면 '$expected' 인자가 필요합니다.")),
    );
  }
}

/// 라우트 인자 타입 불일치 안내
class _BadArgsScreen extends StatelessWidget {
  final String routeName;
  final String expected;
  const _BadArgsScreen({super.key, required this.routeName, required this.expected});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("$routeName 인자 오류")),
      body: Center(child: Text("전달된 인자 타입이 잘못되었습니다. 기대 타입: $expected")),
    );
  }
}
