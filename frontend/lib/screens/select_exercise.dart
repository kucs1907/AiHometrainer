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
    int firstTrue = exercises.indexWhere((e) => e['selected'] == true);
    bool kept = false;
    for (final e in exercises) {
      if (e['selected'] == true && !kept) {
        kept = true;
      } else {
        e['selected'] = false;
      }
    }
    if (!kept && exercises.isNotEmpty) {
      exercises[0]['selected'] = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom; // ⬅️ 홈 바 높이

    return Scaffold(
      backgroundColor: Colors.white,
      // ⬇️ 하단 SafeArea로 홈 바 피하기 (상단은 기존 여백 유지하려고 false)
      body: SafeArea(
        top: false,
        bottom: true,
        child: Padding(
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
                          final bool wasSelected = exercise['selected'] as bool;
                          for (int i = 0; i < exercises.length; i++) {
                            exercises[i]['selected'] = false;
                          }
                          exercises[index]['selected'] = !wasSelected;
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
              // ⬇️ 버튼 아래에 홈 바 높이만큼 여유를 더 줌
              Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
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
