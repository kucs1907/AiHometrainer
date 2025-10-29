// frontend/lib/services/exercise_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/env.dart';
import '../models/exercise_session.dart';

const _baseUrl = Env.restBase; // 한 곳에서 관리

Future<List<ExerciseSession>> fetchExerciseHistory(int userId) async {
  final url = Uri.parse('$_baseUrl/exercise/history?user_id=$userId');
  final res = await http.get(url);

  if (res.statusCode != 200) {
    throw Exception('운동 기록 로드 실패: ${res.statusCode} ${res.body}');
  }

  final decoded = json.decode(res.body);
  if (decoded is! List) {
    throw Exception('예상과 다른 JSON 형식: ${res.body}');
  }

  final out = <ExerciseSession>[];
  for (final item in decoded) {
    try {
      if (item is Map<String, dynamic>) {
        out.add(ExerciseSession.fromJson(item));
      } else {
        // ignore: avoid_print
        print('⚠️ unexpected item type: $item');
      }
    } catch (err) {
      // 문제되는 아이템은 건너뛰고 로그만 남김
      // ignore: avoid_print
      print('⚠️ bad item skipped: $item\n$err');
    }
  }
  return out;
}
