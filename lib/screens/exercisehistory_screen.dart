import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:fl_chart/fl_chart.dart';

class ExerciseHistoryScreen extends StatefulWidget {
  const ExerciseHistoryScreen({super.key});

  @override
  State<ExerciseHistoryScreen> createState() => _ExerciseHistoryScreenState();
}

class _ExerciseHistoryScreenState extends State<ExerciseHistoryScreen> {
  List<Map<String, dynamic>> fullHistory = [
    {"date": "2025-07-20", "type": "스쿼트", "count": 12},
    {"date": "2025-07-20", "type": "딥스", "count": 6},
    {"date": "2025-07-19", "type": "푸쉬업", "count": 10},
    {"date": "2025-07-18", "type": "딥스", "count": 8},
    {"date": "2025-07-17", "type": "스쿼트", "count": 15},
    {"date": "2025-07-16", "type": "딥스", "count": 6},
  ];

  String filterType = '전체';
  String sortMode = '최신순';
  DateTime selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.week;

  final Map<String, Color> exerciseColors = {
    '스쿼트': Colors.teal,
    '푸쉬업': Colors.blue,
    '딥스': Colors.pink,
  };

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> filtered = fullHistory
        .where((e) =>
    (filterType == '전체' || e['type'] == filterType))
        .toList();

    filtered.sort((a, b) {
      int result =
      DateTime.parse(a['date']).compareTo(DateTime.parse(b['date']));
      return sortMode == '최신순' ? -result : result;
    });

    // 선택한 날짜만 필터링
    String selectedDateStr = DateFormat('yyyy-MM-dd').format(selectedDay);
    List<Map<String, dynamic>> dayHistory = filtered
        .where((e) => e['date'] == selectedDateStr)
        .toList();

    int total = dayHistory.fold<int>(0, (p, e) => p + (e['count'] as int));
    double avg =
    dayHistory.isEmpty ? 0 : total / dayHistory.length;

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
          _buildBarChart(dayHistory), // 선택한 날짜용 막대그래프
          const Divider(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: dayHistory.length,
              itemBuilder: (context, index) {
                final item = dayHistory[index];
                return ListTile(
                  leading: Icon(Icons.fitness_center,
                      color: exerciseColors[item['type']] ?? Colors.grey),
                  title: Text('${item["type"]} - ${item["count"]}회'),
                  subtitle: Text(item["date"]),
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
            items: ['전체', '스쿼트', '푸쉬업', '딥스']
                .map((e) => DropdownMenuItem(
              value: e,
              child: Text(e),
            ))
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  filterType = value;
                });
              }
            },
          ),
          const SizedBox(width: 10),
          DropdownButton<String>(
            value: _calendarFormat == CalendarFormat.week ? '주간' : '월간',
            items: ['주간', '월간']
                .map((e) => DropdownMenuItem(
              value: e,
              child: Text(e),
            ))
                .toList(),
            onChanged: (value) {
              setState(() {
                _calendarFormat =
                value == '주간' ? CalendarFormat.week : CalendarFormat.month;
              });
            },
          ),
          const Spacer(),
          DropdownButton<String>(
            value: sortMode,
            items: ['최신순', '오래된 순']
                .map((e) => DropdownMenuItem(
              value: e,
              child: Text(e),
            ))
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  sortMode = value;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarHeatmap() {
    return TableCalendar(
      firstDay: DateTime.utc(2025, 7, 1),
      lastDay: DateTime.utc(2025, 12, 31),
      focusedDay: selectedDay,
      calendarFormat: _calendarFormat,
      selectedDayPredicate: (day) => isSameDay(day, selectedDay),
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, day, focusedDay) {
          final eventsForDay = fullHistory.where((e) =>
          e['date'] == DateFormat('yyyy-MM-dd').format(day));
          if (eventsForDay.isEmpty) return null;

          int totalCount =
          eventsForDay.fold<int>(0, (p, e) => p + (e['count'] as int));

          return Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(totalCount / 20),
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
      onDaySelected: (selected, focused) {
        setState(() {
          selectedDay = selected;
        });
      },
    );
  }

  Widget _buildBarChart(List<Map<String, dynamic>> data) {
    if (data.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text("이 날의 운동 기록이 없습니다."),
      );
    }

    final Map<String, int> summary = {};

    for (var item in data) {
      summary[item['type']] =
          (summary[item['type']] ?? 0) + (item['count'] as int);
    }

    final barGroups = summary.entries.toList().asMap().entries.map((entry) {
      int index = entry.key;
      String type = entry.value.key;
      int count = entry.value.value;
      Color barColor = exerciseColors[type] ?? Colors.grey;

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: count.toDouble(),
            color: barColor,
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
                    return Text(summary.keys.elementAt(value.toInt()),
                        style: const TextStyle(fontSize: 12));
                  },
                ),
              ),
              leftTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: true, interval: 5)),
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
