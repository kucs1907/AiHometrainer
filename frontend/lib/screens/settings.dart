import 'package:flutter/material.dart';
import '../services/push_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushEnabled = true;
  TimeOfDay _time = const TimeOfDay(hour: 20, minute: 0);
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await PushService.fetchPrefs();
    if (prefs != null) {
      setState(() {
        _pushEnabled = prefs["enabled"] ?? true;
        _time = TimeOfDay(hour: (prefs["hour"] ?? 20), minute: (prefs["minute"] ?? 0));
      });
    }
    setState(() => _loading = false);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    final ok = await PushService.updatePrefs(enabled: _pushEnabled, time: _time);
    setState(() => _loading = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? "알림 설정이 저장되었습니다." : "저장 실패"),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text("알림 설정")),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text("푸시 알림"),
            subtitle: const Text("설정한 시간에 하루 1회 발송"),
            value: _pushEnabled,
            onChanged: (v) => setState(() => _pushEnabled = v),
          ),
          ListTile(
            title: const Text("알림 시간"),
            subtitle: Text("${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}"),
            trailing: const Icon(Icons.access_time),
            onTap: _pickTime,
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _save,
              child: const Text("저장"),
            ),
          )
        ],
      ),
    );
  }
}
