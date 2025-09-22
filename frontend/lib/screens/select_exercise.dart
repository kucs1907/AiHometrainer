// lib/screens/select_exercise.dart
import 'package:flutter/material.dart';
import 'live_feedback_screen.dart';

class SelectExerciseScreen extends StatefulWidget {
  const SelectExerciseScreen({super.key});

  @override
  State<SelectExerciseScreen> createState() => _SelectExerciseScreenState();
}

class _SelectExerciseScreenState extends State<SelectExerciseScreen> {
  final List<Map<String, dynamic>> exercises = [
    {'title': '딥스',     'selected': true,  'image': 'assets/images/dips.png'},
    {'title': '플랭크',   'selected': true,  'image': 'assets/images/plank.png'},
    {'title': '턱걸이',   'selected': false, 'image': 'assets/images/pullup.png'},
    {'title': '팔굽혀펴기','selected': false, 'image': 'assets/images/pushup.png'},
    {'title': '스쿼트',   'selected': true,  'image': 'assets/images/squat.png'},
  ];

  @override
  void initState() {
    super.initState();
    // 초기 데이터에서 여러 개 true인 것을 하나만 남기고 나머지는 false로 정규화
    int firstTrue = exercises.indexWhere((e) => e['selected'] == true);
    bool kept = false;
    for (final e in exercises) {
      if (e['selected'] == true && !kept) {
        kept = true; // 첫 true만 유지
      } else {
        e['selected'] = false;
      }
    }
    // 모두 false였다면 첫 항목만 기본 선택(원하면 제거해도 됨)
    if (!kept && exercises.isNotEmpty) {
      exercises[0]['selected'] = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.only(top: 48.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 10),
            const Text(
              '운동 선택',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0A0615),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: exercises.length,
                padding: const EdgeInsets.symmetric(horizontal: 15),
                itemBuilder: (context, index) {
                  final exercise = exercises[index];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        // 단일 선택: 탭한 카드만 토글, 나머지는 전부 false
                        final bool wasSelected = exercise['selected'] as bool;
                        for (int i = 0; i < exercises.length; i++) {
                          exercises[i]['selected'] = false;
                        }
                        // 같은 카드 다시 누르면 해제도 가능하게 하려면 아래처럼 토글
                        exercises[index]['selected'] = !wasSelected;
                        // 항상 하나는 선택되게 하려면 위 한 줄 대신:
                        // exercises[index]['selected'] = true;
                      });
                    },
                    child: _buildExerciseCard(
                      imageUrl: exercise['image'],
                      title: exercise['title'],
                      selected: exercise['selected'],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  onPressed: () {
                    // 단일 선택이므로 첫 번째 true만 취함
                    final sel = exercises.firstWhere(
                      (e) => e['selected'] == true,
                      orElse: () => {},
                    );
                    if (sel.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("하나의 운동을 선택해주세요.")),
                      );
                      return;
                    }
                    final selectedTitle = sel['title'] as String;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            LiveFeedbackScreen(selectedExercises: [selectedTitle]),
                      ),
                    );
                  },
                  child: const Text(
                    '운동 시작',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseCard({
    required String imageUrl,
    required String title,
    required bool selected,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E9EF)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Image.asset(imageUrl, width: 54, height: 54),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFD9DFE7), width: 2),
              color: selected ? const Color(0xFFF25D29) : Colors.white,
            ),
          )
        ],
      ),
    );
  }
}
