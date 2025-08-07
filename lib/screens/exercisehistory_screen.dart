// lib/screens/exercisehistory_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:fl_chart/fl_chart.dart';

import '../models/exercise_log.dart';
import '../services/exercise_service.dart';

class ExerciseHistoryScreen extends StatefulWidget {
  final int userId;
  const ExerciseHistoryScreen({super.key, required this.userId});

  @override
  State<ExerciseHistoryScreen> createState() => _ExerciseHistoryScreenState();
}

class _ExerciseHistoryScreenState extends State<ExerciseHistoryScreen> {
  // 백엔드에서 받아온 기록 맵
  Map<DateTime, List<ExerciseLog>> historyByDate = {};
  // 운동 타입 ID → 이름 맵
  Map<int, String> typeNameMap = {};
  bool _loading = true;

  // UI 상태
  String filterType = '전체';
  String sortMode = '최신순';
  DateTime selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;

  // 막대그래프용 컬러 매핑
  final Map<String, Color> exerciseColors = {
    '스쿼트': Colors.teal,
    '푸쉬업': Colors.blue,
    '딥스': Colors.pink,
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final logs  = await fetchExerciseHistory(widget.userId);
      final types = await fetchExerciseTypes();
      typeNameMap = {for (var t in types) t.id: t.name};

      final tmp = <DateTime, List<ExerciseLog>>{};
      for (var log in logs) {
        final key = DateTime(log.timestamp.year, log.timestamp.month, log.timestamp.day);
        tmp.putIfAbsent(key, () => []).add(log);
      }

      if (!mounted) return;
      setState(() {
        historyByDate = tmp;
        final days = historyByDate.keys.toList()..sort();
        if (days.isNotEmpty) {
          selectedDay = days.last;
          _focusedDay = days.last;
        }
        _loading = false;
      });
    } catch (e) {
      debugPrint('🚨 운동 기록 로드 오류: $e');
      if (!mounted) return;
      setState(() {
        historyByDate = {};
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text("운동 이력")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // 선택 날짜의 키 생성 후 조회
    final key = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
    final dayLogs = historyByDate[key] ?? [];

    // 타입 필터링
    final filtered = filterType == '전체'
        ? dayLogs
        : dayLogs.where((l) => typeNameMap[l.exerciseTypeId] == filterType);

    // 정렬
    final sortedLogs = filtered.toList()
      ..sort((a, b) {
        return sortMode == '최신순'
            ? b.timestamp.compareTo(a.timestamp)
            : a.timestamp.compareTo(b.timestamp);
      });

    // 총합·평균
    final total = sortedLogs.fold<int>(0, (sum, l) => sum + l.count);
    final avg   = sortedLogs.isEmpty ? 0.0 : total / sortedLogs.length;

    return Scaffold(
      appBar: AppBar(title: const Text("운동 이력")),
      body: Column(
        children: [
          _buildFilterRow(),
          _buildCalendarHeatmap(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Text("총 횟수: $total 회"),
                const SizedBox(width: 16),
                Text("평균: ${avg.toStringAsFixed(1)} 회"),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _buildBarChart(sortedLogs),
          const Divider(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: sortedLogs.length,
              itemBuilder: (context, idx) {
                final log = sortedLogs[idx];
                final name = typeNameMap[log.exerciseTypeId] ?? '알수없음';
                return ListTile(
                  leading: Icon(
                    Icons.fitness_center,
                    color: exerciseColors[name] ?? Colors.grey,
                  ),
                  title: Text('$name – ${log.count}회'),
                  subtitle: Text(
                    DateFormat('yyyy-MM-dd HH:mm').format(log.timestamp),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          DropdownButton<String>(
            value: filterType,
            items: ['전체', ...typeNameMap.values.toSet()]
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => filterType = v!),
          ),
          const SizedBox(width: 10),
          DropdownButton<String>(
            value: _calendarFormat == CalendarFormat.week ? '주간' : '월간',
            items: const ['주간', '월간']
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() {
              _calendarFormat =
                  v == '주간' ? CalendarFormat.week : CalendarFormat.month;
            }),
          ),
          const Spacer(),
          DropdownButton<String>(
            value: sortMode,
            items: const ['최신순', '오래된 순']
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => sortMode = v!),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarHeatmap() {
    return TableCalendar(
      firstDay: DateTime.utc(2025, 1, 1),
      lastDay: DateTime.now(),
      focusedDay: _focusedDay,
      calendarFormat: _calendarFormat,
      selectedDayPredicate: (d) => isSameDay(d, selectedDay),
      eventLoader: (day) {
        final key = DateTime(day.year, day.month, day.day);
        return historyByDate[key] ?? [];
      },
      onDaySelected: (newSelected, newFocused) {
        setState(() {
          selectedDay = newSelected;
          _focusedDay = newFocused;
        });
      },
      onPageChanged: (newFocused) {
        setState(() {
          _focusedDay = newFocused;
        });
      },
      onFormatChanged: (format) {
        setState(() {
          _calendarFormat = format;
        });
      },
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (ctx, day, _) {
          final key = DateTime(day.year, day.month, day.day);
          final logs = historyByDate[key] ?? [];
          if (logs.isEmpty) return null;
          final count = logs.fold<int>(0, (s, l) => s + l.count);
          return Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity((count / 20).clamp(0, 1)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '${day.day}',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBarChart(List<ExerciseLog> data) {
    if (data.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text("이 날의 운동 기록이 없습니다."),
      );
    }

    final summary = <String, int>{};
    for (var l in data) {
      final name = typeNameMap[l.exerciseTypeId]!;
      summary[name] = (summary[name] ?? 0) + l.count;
    }

    final barGroups = summary.entries.toList().asMap().entries.map((e) {
      final idx  = e.key;
      final type = e.value.key;
      final cnt  = e.value.value;
      return BarChartGroupData(
        x: idx,
        barRods: [
          BarChartRodData(
            toY: cnt.toDouble(),
            color: exerciseColors[type] ?? Colors.grey,
            width: 18,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
        showingTooltipIndicators: [0],
      );
    }).toList();

    return SizedBox(
      height: 180,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            barTouchData: BarTouchData(enabled: true),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, _) {
                    return Text(
                      summary.keys.elementAt(value.toInt()),
                      style: const TextStyle(fontSize: 12),
                    );
                  },
                ),
              ),
              leftTitles:
                  AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 5)),
              rightTitles:
                  AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:
                  AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            barGroups: barGroups,
            gridData: FlGridData(show: true),
          ),
        ),
      ),
    );
  }
}
