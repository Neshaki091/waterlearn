/// Model đại diện tiến trình học của người dùng.
class UserProgress {
  final String id;
  final String userId;
  final String lessonId;
  final String? classId;
  final DateTime completedAt;

  const UserProgress({
    required this.id,
    required this.userId,
    required this.lessonId,
    this.classId,
    required this.completedAt,
  });

  factory UserProgress.fromJson(Map<String, dynamic> json) => UserProgress(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    lessonId: json['lesson_id'] as String,
    classId: json['class_id'] as String?,
    completedAt: DateTime.parse(json['completed_at'] as String),
  );
}
