// lib/models/exercise_type.dart
class ExerciseType {
  final int id;
  final String name;

  ExerciseType({required this.id, required this.name});

  factory ExerciseType.fromJson(Map<String, dynamic> json) {
    return ExerciseType(
      id: json['id'],
      name: json['name'],
    );
  }
}
