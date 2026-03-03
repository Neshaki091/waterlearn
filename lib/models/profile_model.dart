/// Model đại diện cho profile người dùng trong hệ thống WaterLearn.
class UserProfile {
  final String id;
  final String? fullName;
  final int totalPoints;
  final int streak;
  final int hearts;
  final String? currentClassId;

  const UserProfile({
    required this.id,
    this.fullName,
    this.totalPoints = 0,
    this.streak = 0,
    this.hearts = 5,
    this.currentClassId,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'] as String,
    fullName: json['full_name'] as String?,
    totalPoints: (json['total_points'] as int?) ?? 0,
    streak: (json['streak'] as int?) ?? 0,
    hearts: (json['hearts'] as int?) ?? 5,
    currentClassId: json['current_class_id'] as String?,
  );

  UserProfile copyWith({
    String? fullName,
    int? totalPoints,
    int? streak,
    int? hearts,
    String? currentClassId,
  }) => UserProfile(
    id: id,
    fullName: fullName ?? this.fullName,
    totalPoints: totalPoints ?? this.totalPoints,
    streak: streak ?? this.streak,
    hearts: hearts ?? this.hearts,
    currentClassId: currentClassId ?? this.currentClassId,
  );
}
