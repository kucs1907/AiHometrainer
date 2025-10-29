// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import 'services/push_service.dart';

import 'config/env.dart';

// Screens
import 'screens/onboarding_screen.dart';
import 'screens/home.dart';
import 'screens/select_exercise.dart';
import 'screens/exercisehistory_screen.dart';
import 'screens/live_feedback_screen.dart';
import 'screens/settings.dart';
import 'screens/session_result_screen.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  KakaoSdk.init(nativeAppKey: '26a7ded3a7a8401698e45b4688ea24c7');

  await PushService.init();
  PushService.configureServer(Env.restBase);
  PushService.configureUser("1"); // TODO: 로그인 사용자 ID로 교체

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // 안전 파싱 유틸
  Object? _routeArg(BuildContext context) =>
      ModalRoute.of(context)?.settings.arguments;

  int _parseUserId(Object? arg, {int fallback = 0}) {
    if (arg is int) return arg;
    if (arg is String) return int.tryParse(arg) ?? fallback;
    return fallback;
  }

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
        '/session_result': (context) => const SessionResultScreen(),

        // ✅ 안전 파싱으로 교체
        '/history': (context) {
          final arg = _routeArg(context);
          final userId = _parseUserId(arg, fallback: 1); // 기본값 1
          return ExerciseHistoryScreen(userId: userId);
        },

        // ✅ arguments → List<String>로 안전 변환 후 주입
        '/live_feedback': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          if (args == null) {
            return const _MissingArgsScreen(
              routeName: '/live_feedback',
              expected: 'List<String> selectedExercises',
            );
          }

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
