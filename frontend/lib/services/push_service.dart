import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PushService {
  static bool _initialized = false;
  static String? _serverBaseUrl;
  static String? _userId;
  static String? _token;

  static Future<void> init() async {
    if (_initialized) return;
    await Firebase.initializeApp();
    final messaging = FirebaseMessaging.instance;

    if (Platform.isAndroid) {
      await messaging.requestPermission();
    }

    _token = await messaging.getToken();

    // 포그라운드 수신(필요시 flutter_local_notifications로 트레이 표시 추가 가능)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("[FCM] onMessage: ${message.notification?.title} - ${message.notification?.body}");
    });

    _initialized = true;
  }

  static void configureServer(String baseUrl) {
    _serverBaseUrl = baseUrl;
  }

  static void configureUser(String userId) async {
    _userId = userId;
    await _maybeUploadToken();
  }

  static Future<void> _maybeUploadToken() async {
    if (_serverBaseUrl == null || _userId == null || _token == null) return;
    final uri = Uri.parse("$_serverBaseUrl/notification/register_token");
    try {
      await http.post(uri,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"user_id": _userId, "token": _token, "platform": "android"}));
    } catch (e) {
      debugPrint("[PushService] register_token error: $e");
    }
  }

  // --- Preferences API ---
  static Future<Map<String, dynamic>?> fetchPrefs() async {
    if (_serverBaseUrl == null || _userId == null) return null;
    final uri = Uri.parse("$_serverBaseUrl/notification/prefs?user_id=$_userId");
    try {
      final r = await http.get(uri);
      if (r.statusCode == 200) return jsonDecode(r.body);
    } catch (e) {
      debugPrint("[PushService] fetchPrefs error: $e");
    }
    return null;
  }

  static Future<bool> updatePrefs({required bool enabled, required TimeOfDay time, String timezone = "Asia/Seoul"}) async {
    if (_serverBaseUrl == null || _userId == null) return false;
    final uri = Uri.parse("$_serverBaseUrl/notification/prefs");
    try {
      final r = await http.put(uri,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "user_id": _userId,
            "enabled": enabled,
            "hour": time.hour,
            "minute": time.minute,
            "timezone": timezone
          }));
      return r.statusCode == 200;
    } catch (e) {
      debugPrint("[PushService] updatePrefs error: $e");
      return false;
    }
  }
}
