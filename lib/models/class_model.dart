/// Model đại diện cho một lớp học trong hệ thống WaterLearn.
class ClassModel {
  final String id;
  final String name;
  final String? description;
  final String level; // beginner | intermediate | advanced

  const ClassModel({
    required this.id,
    required this.name,
    this.description,
    required this.level,
  });

  factory ClassModel.fromJson(Map<String, dynamic> json) => ClassModel(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String?,
    level: json['level'] as String? ?? 'beginner',
  );

  /// Tên tiếng Việt của level
  String get levelLabel {
    switch (level) {
      case 'intermediate':
        return '🟡 Trung cấp';
      case 'advanced':
        return '🔴 Nâng cao';
      default:
        return '🟢 Nhập môn';
    }
  }
}
