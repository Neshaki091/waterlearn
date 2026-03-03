// ─────────────────────────────────────────────────────────────
// WaterLearn – Course Models
// Hỗ trợ đầy đủ các loại quiz: multiple_choice, find_error, fix_syntax...
// ─────────────────────────────────────────────────────────────

enum QuizType {
  multipleChoice,
  trueFalse,
  fillBlank,
  codeOutput,
  findError,
  fixSyntax;

  static QuizType fromString(String? s) {
    switch (s) {
      case 'true_false':
        return QuizType.trueFalse;
      case 'fill_blank':
        return QuizType.fillBlank;
      case 'code_output':
        return QuizType.codeOutput;
      case 'find_error':
        return QuizType.findError;
      case 'fix_syntax':
        return QuizType.fixSyntax;
      default:
        return QuizType.multipleChoice;
    }
  }
}

// ─── Section (một mục trong chương) ──────────────────────────
class Section {
  final String heading;
  final String body;

  const Section({required this.heading, required this.body});

  factory Section.fromJson(Map<String, dynamic> json) => Section(
    heading: json['heading'] as String? ?? '',
    body: json['body'] as String? ?? '',
  );
}

// ─── Chapter (nội dung bài giảng) ────────────────────────────
class Chapter {
  final String title;
  final String content; // Backward compat: old format
  final List<Section> sections; // New format: list of sections

  const Chapter({
    required this.title,
    this.content = '',
    this.sections = const [],
  });

  /// Hỗ trợ cả format cũ (content string) lẫn format mới (sections list)
  factory Chapter.fromJson(Map<String, dynamic> json) {
    final sections =
        json['sections'] != null
            ? (json['sections'] as List)
                .map((s) => Section.fromJson(s as Map<String, dynamic>))
                .toList()
            : <Section>[];

    return Chapter(
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      sections: sections,
    );
  }

  /// Trả về toàn bộ nội dung dạng Markdown
  String get fullMarkdown {
    if (sections.isNotEmpty) {
      return sections
          .map((s) => '### ${s.heading}\n\n${s.body}')
          .join('\n\n---\n\n');
    }
    return content;
  }
}

// ─── Quiz ────────────────────────────────────────────────────
class Quiz {
  final String id;
  final String lessonId;
  final String question;
  final QuizType quizType;
  final List<String> options;
  final String answer;
  final String? explanation;

  // Syntax Traps fields
  final String? buggyCode;
  final int? errorLine;
  final String? fixedCode;
  final String codeLanguage;
  final int xpReward;

  const Quiz({
    required this.id,
    required this.lessonId,
    required this.question,
    required this.quizType,
    required this.options,
    required this.answer,
    this.explanation,
    this.buggyCode,
    this.errorLine,
    this.fixedCode,
    this.codeLanguage = 'python',
    this.xpReward = 10,
  });

  factory Quiz.fromJson(Map<String, dynamic> json) => Quiz(
    id: json['id'] as String? ?? '',
    lessonId: json['lesson_id'] as String? ?? '',
    question: json['question'] as String? ?? '',
    quizType: QuizType.fromString(json['quiz_type'] as String?),
    options:
        json['options'] != null
            ? List<String>.from(json['options'] as List)
            : [],
    answer: json['answer'] as String? ?? '',
    explanation: json['explanation'] as String?,
    buggyCode: json['buggy_code'] as String?,
    errorLine: json['error_line'] as int?,
    fixedCode: json['fixed_code'] as String?,
    codeLanguage: json['code_language'] as String? ?? 'python',
    xpReward: json['xp_reward'] as int? ?? 10,
  );
}

// ─── Lesson ──────────────────────────────────────────────────
class Lesson {
  final String id;
  final String title;
  final String topic;
  final List<Chapter> chapters;
  final String? classId;

  const Lesson({
    required this.id,
    required this.title,
    required this.topic,
    required this.chapters,
    this.classId,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) => Lesson(
    id: json['id'] as String,
    title: json['title'] as String,
    topic: json['topic'] as String,
    chapters:
        (json['chapters'] as List? ?? [])
            .map((c) => Chapter.fromJson(c as Map<String, dynamic>))
            .toList(),
    classId: json['class_id'] as String?,
  );
}
