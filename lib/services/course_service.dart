import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/course_models.dart';

class CourseService {
  final SupabaseClient _client;

  CourseService(this._client);

  /// Gọi Edge Function `generate-course` và trả về lesson_id.
  /// [classId] là tuỳ chọn – nếu có sẽ gửi kèm để prompt theo level của lớp.
  Future<String> requestAICourse(String topic, {String? classId}) async {
    final body = <String, dynamic>{'topic': topic};
    if (classId != null) body['class_id'] = classId;

    final response = await _client.functions.invoke(
      'generate-course',
      body: body,
    );

    if (response.status != 201 && response.status != 202) {
      final errorBody =
          response.data is String
              ? jsonDecode(response.data as String)
              : response.data as Map;
      throw Exception(
        'Failed to generate course: ${errorBody['error'] ?? response.status}',
      );
    }

    final data =
        response.data is String
            ? jsonDecode(response.data as String) as Map<String, dynamic>
            : response.data as Map<String, dynamic>;

    return data['lesson_id'] as String;
  }

  /// Lấy lesson theo ID từ bảng `lessons`.
  Future<Lesson> fetchLesson(String lessonId) async {
    final data =
        await _client.from('lessons').select().eq('id', lessonId).single();
    return Lesson.fromJson(data);
  }

  /// Lấy danh sách quiz của một lesson từ bảng `quizzes`.
  Future<List<Quiz>> fetchQuizzes(String lessonId) async {
    final data = await _client
        .from('quizzes')
        .select()
        .eq('lesson_id', lessonId)
        .order('created_at');

    return (data as List)
        .map((q) => Quiz.fromJson(q as Map<String, dynamic>))
        .toList();
  }
}
