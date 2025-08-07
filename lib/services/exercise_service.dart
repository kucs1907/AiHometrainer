// lib/services/exercise_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/exercise_type.dart';
import '../models/exercise_log.dart';

const _baseUrl = 'http://192.168.219.102:8000';  // 실제 서버 주소/포트로 변경

Future<List<ExerciseType>> fetchExerciseTypes() async {
  final res = await http.get(Uri.parse('$_baseUrl/exercise/type'));
  if (res.statusCode == 200) {
    final List list = json.decode(res.body);
    return list.map((e) => ExerciseType.fromJson(e)).toList();
  }
  throw Exception('운동 종류 로드 실패: ${res.statusCode}');
}

Future<List<ExerciseLog>> fetchExerciseHistory(int userId) async {
  final res = await http.get(
    Uri.parse('$_baseUrl/exercise/history?user_id=$userId')
  );
  if (res.statusCode == 200) {
    final List list = json.decode(res.body);
    return list.map((e) => ExerciseLog.fromJson(e)).toList();
  }
  throw Exception('운동 기록 로드 실패: ${res.statusCode}');
}
