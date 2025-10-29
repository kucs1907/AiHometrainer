// frontend/lib/screens/exercisehistory_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:fl_chart/fl_chart.dart';

import '../models/exercise_session.dart';
import '../services/exercise_service.dart';

class ExerciseHistoryScreen extends StatefulWidget {
  final int userId;
  const ExerciseHistoryScreen({super.key, required this.userId});

  @override
  State<ExerciseHistoryScreen> createState() => _ExerciseHistoryScreenState();
}

class _ExerciseHistoryScreenState extends State<ExerciseHistoryScreen> {
  Map<DateTime, List<ExerciseSession>> historyByDate = {};
  bool _loading = true;

  String filterType = '전체';
  String sortMode = '최신순';
  DateTime selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;

  final List<Color> palette = [
    Colors.black87,
    Colors.grey.shade800,
    Colors.grey.shade700,
    Colors.grey.shade600,
    Colors.grey.shade500,
    Colors.grey.shade400,
    Colors.grey.shade300,
    Colors.grey.shade900,
  ];
  final Map<String, Color> exerciseColors = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final sessions = await fetchExerciseHistory(widget.userId);

      final tmp = <DateTime, List<ExerciseSession>>{};
      for (var s in sessions) {
        final key = DateTime(s.timestamp.year, s.timestamp.month, s.timestamp.day);
        tmp.putIfAbsent(key, () => []).add(s);
      }

      final names = <String>{};
      for (final list in tmp.values) {
        for (final s in list) {
          names.add(s.exercise);
        }
      }
      final sortedNames = names.toList()..sort();
      for (var i = 0; i < sortedNames.length; i++) {
        exerciseColors[sortedNames[i]] = palette[i % palette.length];
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
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text("운동 이력"),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0.5,
        ),
        body: const Center(child: CircularProgressIndicator(color: Colors.black)),
      );
    }

    final viewPadding = MediaQuery.of(context).viewPadding;
    final size = MediaQuery.of(context).size;
    final chartHeight = (size.height * 0.28).clamp(160, 240).toDouble();

    final key = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
    final daySessions = historyByDate[key] ?? [];

    final filtered = filterType == '전체'
        ? daySessions
        : daySessions.where((s) => s.exercise == filterType);

    final sorted = filtered.toList()
      ..sort((a, b) => sortMode == '최신순'
          ? b.timestamp.compareTo(a.timestamp)
          : a.timestamp.compareTo(b.timestamp));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("운동 이력"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: viewPadding.bottom + 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildFilterRow(),
              _buildCalendar(),              // ← 수정된 캘린더
              const SizedBox(height: 10),
              _buildBarChart(sorted, height: chartHeight),
              const Divider(height: 24, color: Colors.black12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sorted.length,
                itemBuilder: (context, idx) {
                  final s = sorted[idx];
                  final color = exerciseColors[s.exercise] ?? Colors.black54;
                  final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(s.timestamp);
                  final titleText =
                      '${s.exercise} – ${s.count}회  ·  ${_accuracyText(s)}';

                  return ListTile(
                    leading: Icon(Icons.fitness_center, color: color),
                    title: Text(
                      titleText,
                      style: const TextStyle(color: Colors.black),
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      dateStr,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _accuracyText(ExerciseSession s) {
    final clamped = s.score.clamp(0.0, 1.0);
    final pct = (clamped * 100).toStringAsFixed(1);
    return '정확도 $pct%';
  }

  Widget _buildFilterRow() {
    final allNames = <String>{'전체'};
    for (final list in historyByDate.values) {
      for (final s in list) {
        allNames.add(s.exercise);
      }
    }
    final filterItems = allNames.toList()..sort((a, b) {
      if (a == '전체') return -1;
      if (b == '전체') return 1;
      return a.compareTo(b);
    });

    final textStyle = const TextStyle(color: Colors.black);

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: filterType,
              style: textStyle,
              iconEnabledColor: Colors.black,
              dropdownColor: Colors.white,
              items: filterItems
                  .map((e) => DropdownMenuItem(value: e, child: Text(e, style: textStyle)))
                  .toList(),
              onChanged: (v) => setState(() => filterType = v!),
            ),
          ),
          const SizedBox(width: 10),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _calendarFormat == CalendarFormat.week ? '주간' : '월간',
              style: textStyle,
              iconEnabledColor: Colors.black,
              dropdownColor: Colors.white,
              items: const ['주간', '월간']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() {
                _calendarFormat =
                    v == '주간' ? CalendarFormat.week : CalendarFormat.month;
              }),
            ),
          ),
          const Spacer(),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: sortMode,
              style: textStyle,
              iconEnabledColor: Colors.black,
              dropdownColor: Colors.white,
              items: const ['최신순', '오래된 순']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => sortMode = v!),
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ 원형 데코로 고정(둘 다 circle, borderRadius 사용 안 함)
  Widget _buildCalendar() {
    return TableCalendar(
      firstDay: DateTime.utc(2025, 1, 1),
      lastDay: DateTime.now(),
      focusedDay: _focusedDay,
      calendarFormat: _calendarFormat,
      selectedDayPredicate: (d) => isSameDay(d, selectedDay),

      eventLoader: (day) {
        final key = DateTime(day.year, day.month, day.day);
        return (historyByDate[key] ?? const <ExerciseSession>[])
            .cast<Object>()
            .toList();
      },

      onDaySelected: (newSelected, newFocused) {
        setState(() {
          selectedDay = newSelected;
          _focusedDay = newFocused;
        });
      },
      onPageChanged: (newFocused) => setState(() => _focusedDay = newFocused),
      onFormatChanged: (format) => setState(() => _calendarFormat = format),

      headerStyle: HeaderStyle(
        titleTextStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
        leftChevronIcon: const Icon(Icons.chevron_left, color: Colors.black),
        rightChevronIcon: const Icon(Icons.chevron_right, color: Colors.black),
        formatButtonVisible: false,
      ),
      calendarStyle: CalendarStyle(
        defaultTextStyle: const TextStyle(color: Colors.black),
        weekendTextStyle: const TextStyle(color: Colors.black87),
        outsideTextStyle: const TextStyle(color: Colors.black38),

        // 🔴 여기 두 줄만 핵심 수정: 원형 + borderRadius 제거
        todayDecoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black87, width: 1.5),
          color: Colors.transparent,
        ),
        selectedDecoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black,
        ),
      ),
    );
  }

  Widget _buildBarChart(List<ExerciseSession> data, {double height = 220}) {
    if (data.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          "이 날의 운동 기록이 없습니다.",
          style: TextStyle(color: Colors.black),
        ),
      );
    }

    final summary = <String, int>{};
    for (var s in data) {
      summary[s.exercise] = (summary[s.exercise] ?? 0) + s.count;
    }
    final entries = summary.entries.toList();

    final maxCount = summary.values.isEmpty
        ? 0
        : summary.values.reduce((a, b) => a > b ? a : b);

    double _niceStep(int m) {
      if (m <= 5) return 1;
      if (m <= 10) return 2;
      if (m <= 25) return 5;
      if (m <= 50) return 10;
      if (m <= 100) return 20;
      return 50;
    }

    final step = _niceStep(maxCount);
    final maxY = (((maxCount) / step).ceil() + 1) * step;

    final barGroups = entries.asMap().entries.map((e) {
      final idx = e.key;
      final name = e.value.key;
      final cnt = e.value.value;
      return BarChartGroupData(
        x: idx,
        barRods: [
          BarChartRodData(
            toY: cnt.toDouble(),
            color: exerciseColors[name] ?? Colors.black87,
            width: 18,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    }).toList();

    final gridColor = Colors.black12;
    final labelStyle = const TextStyle(fontSize: 12, color: Colors.black);

    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: BarChart(
          BarChartData(
            minY: 0,
            maxY: maxY.toDouble(),
            alignment: BarChartAlignment.spaceAround,
            gridData: FlGridData(
              show: true,
              horizontalInterval: step.toDouble(),
              getDrawingHorizontalLine: (v) =>
                  FlLine(color: gridColor, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            barTouchData: BarTouchData(enabled: false),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, _) {
                    final i = value.toInt();
                    if (i < 0 || i >= entries.length) return const SizedBox();
                    return Text(entries[i].key, style: labelStyle);
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  interval: step.toDouble(),
                  getTitlesWidget: (value, _) =>
                      Text(value.toInt().toString(),
                          style: const TextStyle(fontSize: 11, color: Colors.black)),
                ),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  getTitlesWidget: (value, _) {
                    final i = value.toInt();
                    if (i < 0 || i >= entries.length) return const SizedBox();
                    final cnt = entries[i].value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '$cnt',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            barGroups: barGroups,
          ),
        ),
      ),
    );
  }
}
