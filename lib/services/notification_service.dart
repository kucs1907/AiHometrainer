// lib/services/notification_service.dart

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';

final _flutterLocalNotifications = FlutterLocalNotificationsPlugin();

class NotificationService {
  /// 사용자가 알림을 켜뒀으면 스케줄링, 아니면 패스
  static Future<void> scheduleIfEnabled() async {
    // (예시) SharedPreferences에서 불러오기
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('alarm_enabled') ?? false;
    if (!enabled) return;

    try {
      await _flutterLocalNotifications.periodicallyShow(
        0,
        '운동 알림',
        '오늘도 운동하실 시간이에요!',
        RepeatInterval.hourly,  // 원하는 주기
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'alarm_channel',
            '운동 알림 채널',
            channelDescription: '운동 리마인더',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        androidAllowWhileIdle: true,
      );
      debugPrint('🔔 알림 스케줄링 성공');
    } on PlatformException catch (e) {
      // 정확 알람 권한이 없거나 다른 플랫폼 에러
      debugPrint('🔔 알림 스케줄링 실패: $e');
    }
  }
}
