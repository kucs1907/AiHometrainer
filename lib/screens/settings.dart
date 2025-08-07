import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationSetting();
  }

  Future<void> _loadNotificationSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notification_enabled') ?? true;
    });
  }

  Future<void> _toggleNotification(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notification_enabled', value);
    if (value) {
      await NotificationService.scheduleIfEnabled();
    } else {
      await NotificationService.cancelAll();
    }
    setState(() {
      _notificationsEnabled = value;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value ? '알림이 켜졌습니다' : '알림이 꺼졌습니다')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('운동 알림 켜기'),
            subtitle: const Text('설정에 따라 알림이 동작합니다'),
            value: _notificationsEnabled,
            onChanged: _toggleNotification,
          ),
        ],
      ),
    );
  }
}
