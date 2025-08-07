import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(InitializationSettings(android: androidInit));
  }

  static Future<void> scheduleIfEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('notification_enabled') ?? true;
    if (!enabled) return;

    await _plugin.periodicallyShow(
      1,
      '운동 알림',
      '오늘 운동하셨나요? 시간이 되었어요 😊',
      RepeatInterval.everyMinute,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'exercise_reminder_channel',
          '운동 알림',
          channelDescription: '운동 미션 알림',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidAllowWhileIdle: true,
    );
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
