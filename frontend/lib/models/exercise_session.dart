// frontend/lib/models/exercise_session.dart

class ExerciseSession {
  final int id;
  final int userId;
  final String exercise;     // '스쿼트' 등
  final int count;           // reps
  final double duration;     // seconds
  final double score;        // correct_ratio/score
  final DateTime timestamp;  // 세션 시작 시각

  ExerciseSession({
    required this.id,
    required this.userId,
    required this.exercise,
    required this.count,
    required this.duration,
    required this.score,
    required this.timestamp,
  });

  // --------- 안전 변환 유틸 ---------
  static int _asInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  static double _asDouble(dynamic v, {double fallback = 0.0}) {
    if (v == null) return fallback;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }

  static DateTime _asDate(dynamic v) {
    // 백엔드가 ISO 문자열(KST naive) 내려줌
    if (v is String) {
      try { return DateTime.parse(v).toLocal(); } catch (_) {}
    } else if (v is DateTime) {
      return v.toLocal();
    }
    // 파싱 실패 시 지금 시각
    return DateTime.now();
  }
  // ---------------------------------

  factory ExerciseSession.fromJson(Map<String, dynamic> json) {
    return ExerciseSession(
      id: _asInt(json['id']),
      userId: _asInt(json['user_id']),
      exercise: (json['exercise'] as String?)?.trim().isNotEmpty == true
          ? (json['exercise'] as String).trim()
          : '기타',
      count: _asInt(json['count']),
      duration: _asDouble(json['duration']),
      score: _asDouble(json['score']),
      timestamp: _asDate(json['timestamp']),
    );
  }
}
