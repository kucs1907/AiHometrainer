// lib/screens/settings.dart
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
        _time = TimeOfDay(
          hour: (prefs["hour"] ?? 20),
          minute: (prefs["minute"] ?? 0),
        );
      });
    }
    setState(() => _loading = false);
  }

  String _fmt2(int v) => v.toString().padLeft(2, '0');

  Future<void> _openTimeDropdown() async {
    int tempHour = _time.hour;
    int tempMinute = _time.minute;

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          title: const Text(
            '알림 시간 선택',
            style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black),
          ),
          content: SizedBox(
            width: 280,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 시 선택 (00~23)
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: tempHour,
                    items: List.generate(
                      24,
                      (i) => DropdownMenuItem(
                        value: i,
                        child: Text(_fmt2(i), style: const TextStyle(color: Colors.black)),
                      ),
                    ),
                    onChanged: (v) => tempHour = v ?? tempHour,
                    decoration: const InputDecoration(
                      labelText: '시',
                      border: OutlineInputBorder(),
                    ),
                    dropdownColor: Colors.white,
                    style: const TextStyle(color: Colors.black),
                  ),
                ),
                const SizedBox(width: 12),
                // 분 선택 (00~59)
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: tempMinute,
                    items: List.generate(
                      60,
                      (i) => DropdownMenuItem(
                        value: i,
                        child: Text(_fmt2(i), style: const TextStyle(color: Colors.black)),
                      ),
                    ),
                    onChanged: (v) => tempMinute = v ?? tempMinute,
                    decoration: const InputDecoration(
                      labelText: '분',
                      border: OutlineInputBorder(),
                    ),
                    dropdownColor: Colors.white,
                    style: const TextStyle(color: Colors.black),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소', style: TextStyle(color: Colors.black54)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                setState(() => _time = TimeOfDay(hour: tempHour, minute: tempMinute));
                Navigator.pop(ctx);
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    final ok = await PushService.updatePrefs(enabled: _pushEnabled, time: _time);
    setState(() => _loading = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? "알림 설정이 저장되었습니다." : "저장 실패")),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: Colors.black)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("알림 설정", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: ListView(
        children: [
          // 푸시 알림 스위치 (모노톤)
          SwitchListTile(
            title: const Text("푸시 알림", style: TextStyle(color: Colors.black)),
            subtitle: const Text("설정한 시간에 하루 1회 발송",
                style: TextStyle(color: Colors.black54)),
            value: _pushEnabled,
            onChanged: (v) => setState(() => _pushEnabled = v),
            activeColor: Colors.white,          // thumb
            activeTrackColor: Colors.black,     // track
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.black26,
          ),

          // 시간 선택 (드롭다운 다이얼로그)
          ListTile(
            title: const Text("알림 시간", style: TextStyle(color: Colors.black)),
            subtitle: Text(
              "${_fmt2(_time.hour)}:${_fmt2(_time.minute)}",
              style: const TextStyle(color: Colors.black87),
            ),
            trailing: const Icon(Icons.schedule, color: Colors.black),
            onTap: _openTimeDropdown,
          ),

          const Divider(color: Colors.black12),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              height: 48,
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  elevation: 0,
                ),
                onPressed: _save,
                child: const Text("저장", style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
