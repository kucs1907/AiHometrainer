class ExerciseLog {
  final int id;
  final int userId;
  final int exerciseTypeId;
  final int count;
  final double duration;
  final double score;
  final DateTime timestamp;

  ExerciseLog({
    required this.id,
    required this.userId,
    required this.exerciseTypeId,
    required this.count,
    required this.duration,
    required this.score,
    required this.timestamp,
  });

  factory ExerciseLog.fromJson(Map<String, dynamic> json) {
    // UTC 파싱 후 toLocal() 호출하여 디바이스 로컬 타임존으로 변환
    final utcTime = DateTime.parse(json['timestamp'] as String);
    return ExerciseLog(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      exerciseTypeId: json['exercise_type_id'] as int,
      count: json['count'] as int,
      duration: (json['duration'] as num).toDouble(),
      score: (json['score'] as num).toDouble(),
      timestamp: utcTime.toLocal(),
    );
  }
}

