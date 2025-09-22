import 'package:flutter/material.dart';

import 'select_exercise.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // ✅ 내부 팝업 알림 로직(타이머/다이얼로그/설정 체크) 완전 제거
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          Positioned(
            top: 70,
            left: 30,
            child: CircleAvatar(
              radius: 25,
              backgroundColor: const Color(0xFFE3E3EA),
              child: const Icon(Icons.calendar_today, color: Colors.black),
            ),
          ),
          Positioned(
            top: 75,
            left: 91,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('friday',
                    style: TextStyle(
                        color: Color(0xFF79797F),
                        fontSize: 16,
                        fontWeight: FontWeight.w300)),
                Text('11 July',
                    style: TextStyle(
                        color: Color(0xFF161626),
                        fontSize: 22,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          Positioned(
            top: 66,
            right: 70,
            child: GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/settings'),
              child: const Icon(Icons.settings, size: 30, color: Colors.black),
            ),
          ),
          Positioned(
            top: 66,
            right: 20,
            child: GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/history'),
              child: Image.asset('assets/images/analysis.png',
                  width: 40, height: 40, fit: BoxFit.contain),
            ),
          ),
          Positioned(
            top: 144,
            left: 30,
            right: 30,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _dayBox('11', 'Fri', false),
                _dayBox('12', 'Sat', true),
                _dayBox('13', 'Sun', false),
                _dayBox('14', 'Mon', false),
              ],
            ),
          ),
          Positioned(
            top: 282,
            left: 30,
            right: 30,
            child: Row(
              children: [
                const CircleAvatar(
                    radius: 28, backgroundColor: Color(0xFF737373)),
                const SizedBox(width: 12),
                const Text('구 찬서',
                    style: TextStyle(
                        color: Color(0xFF161626),
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  height: 30,
                  decoration: BoxDecoration(
                      color: const Color(0xFF3C3DF5),
                      borderRadius: BorderRadius.circular(99)),
                  child: const Center(
                      child: Text('수정',
                          style:
                              TextStyle(color: Colors.white, fontSize: 12))),
                ),
              ],
            ),
          ),
          Positioned(
            top: 352,
            left: 30,
            right: 30,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _infoBox('178 cm', '키'),
                _infoBox('65 kg', '몸무게'),
                _infoBox('28', '나이'),
              ],
            ),
          ),
          Positioned(
            top: 470,
            left: MediaQuery.of(context).size.width / 2 - 100,
            child: GestureDetector(
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SelectExerciseScreen())),
              child: Image.asset('assets/images/start_exercise.png',
                  width: 200, height: 200, fit: BoxFit.contain),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayBox(String day, String label, bool isActive) => Container(
      width: 70,
      height: 85,
      decoration: BoxDecoration(
          color: isActive ? const Color(0xFF2F80ED) : const Color(0xFFE3E3EA),
          borderRadius: BorderRadius.circular(15)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(day,
            style: TextStyle(
                color: isActive ? Colors.white : const Color(0xFF161626),
                fontSize: 30,
                fontWeight: FontWeight.w300)),
        Text(label,
            style: TextStyle(
                color: isActive ? Colors.white : const Color(0xFF79797F),
                fontSize: 18,
                fontWeight: FontWeight.w300))
      ]));

  Widget _infoBox(String value, String label) => Container(
      width: 95,
      height: 65,
      decoration: BoxDecoration(
          color: const Color(0xFF292B37),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
                color: Color(0x111D1617), blurRadius: 40, offset: Offset(0, 10))
          ]),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(value,
            style: const TextStyle(
                color: Color(0xFF3C3DF5),
                fontSize: 14,
                fontWeight: FontWeight.w500)),
        Text(label,
            style: const TextStyle(
                color: Color(0xFFB6B4C1),
                fontSize: 12,
                fontWeight: FontWeight.w400))
      ]));
}
