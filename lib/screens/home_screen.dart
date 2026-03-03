import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/auth_provider.dart';
import '../providers/quiz_session_provider.dart';
import '../services/course_service.dart';
import 'lesson_browser_screen.dart';
import 'lesson_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabase = Supabase.instance.client;
  late final CourseService _courseService;

  List<Map<String, dynamic>> _subjects = [];
  bool _loading = true;
  String? _generatingId; // ID của subject đang generate

  @override
  void initState() {
    super.initState();
    _courseService = CourseService(_supabase);
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    try {
      final data = await _supabase
          .from('classes')
          .select('id, name, description, level')
          .order('level')
          .order('name');

      // Đếm số lesson cho mỗi class
      for (final subject in data) {
        final lessonCount = await _supabase
            .from('lessons')
            .select('id')
            .eq('class_id', subject['id']);
        subject['lesson_count'] = (lessonCount as List).length;
      }

      if (mounted) {
        setState(() {
          _subjects = List<Map<String, dynamic>>.from(data);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  /// Tap vào subject: nếu có lesson → mở, chưa có → generate
  Future<void> _onTapSubject(Map<String, dynamic> subject, bool isAdmin) async {
    final classId = subject['id'] as String;
    final lessonCount = subject['lesson_count'] as int? ?? 0;

    if (lessonCount > 0) {
      // Đã có lesson → kiểm tra status
      final lessons = await _supabase
          .from('lessons')
          .select('id, status')
          .eq('class_id', classId)
          .order('created_at', ascending: false)
          .limit(1);

      if (lessons.isNotEmpty && mounted) {
        final status = lessons[0]['status'] as String? ?? 'ready';
        if (status == 'generating') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⏳ Bài học đang được AI tạo... Quay lại sau nhé!'),
              backgroundColor: Color(0xFF6366F1),
            ),
          );
          return;
        }
        Navigator.of(context).push(
          MaterialPageRoute(
            builder:
                (_) => ChangeNotifierProvider(
                  create: (_) => QuizSessionProvider(),
                  child: LessonView(lessonId: lessons[0]['id']),
                ),
          ),
        );
      }
    } else {
      // Chưa có lesson
      if (!isAdmin) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bài học chưa sẵn sàng. Liên hệ admin để tạo.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Admin → fire-and-forget AI generation
      setState(() => _generatingId = classId);
      try {
        final name = subject['name'] as String;
        await _courseService.requestAICourse(name, classId: classId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '✅ AI đang tạo bài học! Bạn có thể thoát app, quay lại sau 3-5 phút.',
            ),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 5),
          ),
        );
        // Reload subjects to show generating status
        _loadSubjects();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      } finally {
        if (mounted) setState(() => _generatingId = null);
      }
    }
  }

  void _showAddSubjectDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String selectedLevel = 'beginner';

    showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setDialogState) => AlertDialog(
                  backgroundColor: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  title: Text(
                    '➕ Thêm môn học mới',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Tên môn
                        TextField(
                          controller: nameCtrl,
                          style: GoogleFonts.inter(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Tên môn học (VD: Docker, Git...)',
                            hintStyle: GoogleFonts.inter(color: Colors.white38),
                            filled: true,
                            fillColor: const Color(0xFF0F172A),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: const Icon(
                              Icons.book_outlined,
                              color: Color(0xFF6366F1),
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Mô tả
                        TextField(
                          controller: descCtrl,
                          style: GoogleFonts.inter(color: Colors.white),
                          maxLines: 2,
                          decoration: InputDecoration(
                            hintText: 'Mô tả ngắn (tuỳ chọn)',
                            hintStyle: GoogleFonts.inter(color: Colors.white38),
                            filled: true,
                            fillColor: const Color(0xFF0F172A),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: const Icon(
                              Icons.info_outline,
                              color: Color(0xFF6366F1),
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Level selector
                        Text(
                          'Trình độ',
                          style: GoogleFonts.inter(
                            color: Colors.white54,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _LevelChip(
                              label: '🌱 Cơ bản',
                              value: 'beginner',
                              selected: selectedLevel,
                              onTap:
                                  () => setDialogState(
                                    () => selectedLevel = 'beginner',
                                  ),
                            ),
                            const SizedBox(width: 6),
                            _LevelChip(
                              label: '🔥 Trung cấp',
                              value: 'intermediate',
                              selected: selectedLevel,
                              onTap:
                                  () => setDialogState(
                                    () => selectedLevel = 'intermediate',
                                  ),
                            ),
                            const SizedBox(width: 6),
                            _LevelChip(
                              label: '⚡ Nâng cao',
                              value: 'advanced',
                              selected: selectedLevel,
                              onTap:
                                  () => setDialogState(
                                    () => selectedLevel = 'advanced',
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        'Huỷ',
                        style: GoogleFonts.inter(color: Colors.white38),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) return;

                        Navigator.pop(ctx);

                        await _supabase.from('classes').insert({
                          'name': name,
                          'description':
                              descCtrl.text.trim().isNotEmpty
                                  ? descCtrl.text.trim()
                                  : null,
                          'level': selectedLevel,
                        });

                        _loadSubjects(); // Reload
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Thêm',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final userName =
        authProvider.user?.userMetadata?['full_name'] as String? ??
        authProvider.user?.email?.split('@').first ??
        'Bạn';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      floatingActionButton:
          authProvider.isAdmin
              ? FloatingActionButton(
                onPressed: _showAddSubjectDialog,
                backgroundColor: const Color(0xFF6366F1),
                child: const Icon(Icons.add, color: Colors.white),
              )
              : null,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadSubjects,
          color: const Color(0xFF6366F1),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            children: [
              // Top bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFF06B6D4)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Text('💧', style: TextStyle(fontSize: 20)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Xin chào, $userName',
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'Chọn môn để bắt đầu học',
                                style: GoogleFonts.inter(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const LessonBrowserScreen(),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.library_books_outlined,
                          color: Colors.white38,
                        ),
                        tooltip: 'Xem tất cả bài học',
                      ),
                      IconButton(
                        onPressed: () => authProvider.signOut(),
                        icon: const Icon(
                          Icons.logout_rounded,
                          color: Colors.white38,
                        ),
                        tooltip: 'Đăng xuất',
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Section header
              Text(
                '📚 Danh sách môn học',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Chạm vào môn để học. Nếu chưa có bài, AI sẽ tự tạo.',
                style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
              ),
              const SizedBox(height: 16),

              // Subject grid
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF6366F1)),
                  ),
                )
              else if (_subjects.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: Center(
                    child: Column(
                      children: [
                        const Text('📭', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 12),
                        Text(
                          'Chưa có môn nào',
                          style: GoogleFonts.inter(
                            color: Colors.white54,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Bấm + để thêm môn học mới',
                          style: GoogleFonts.inter(
                            color: Colors.white38,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...List.generate(_subjects.length, (i) {
                  final subject = _subjects[i];
                  final isGenerating = _generatingId == subject['id'];
                  return _SubjectCard(
                    subject: subject,
                    isGenerating: isGenerating,
                    isAdmin: authProvider.isAdmin,
                    onTap: () => _onTapSubject(subject, authProvider.isAdmin),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Subject Card ─────────────────────────────────────────────────────────────
class _SubjectCard extends StatelessWidget {
  final Map<String, dynamic> subject;
  final bool isGenerating;
  final bool isAdmin;
  final VoidCallback onTap;

  const _SubjectCard({
    required this.subject,
    required this.isGenerating,
    required this.isAdmin,
    required this.onTap,
  });

  Color _levelColor(String? level) {
    switch (level) {
      case 'intermediate':
        return const Color(0xFFF59E0B);
      case 'advanced':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF10B981);
    }
  }

  String _levelEmoji(String? level) {
    switch (level) {
      case 'intermediate':
        return '🔥';
      case 'advanced':
        return '⚡';
      default:
        return '🌱';
    }
  }

  String _levelLabel(String? level) {
    switch (level) {
      case 'intermediate':
        return 'Trung cấp';
      case 'advanced':
        return 'Nâng cao';
      default:
        return 'Cơ bản';
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = subject['name'] as String? ?? '';
    final desc = subject['description'] as String?;
    final level = subject['level'] as String?;
    final lessonCount = subject['lesson_count'] as int? ?? 0;
    final color = _levelColor(level);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: isGenerating ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  isGenerating
                      ? const Color(0xFF6366F1)
                      : const Color(0xFF334155),
              width: isGenerating ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              // Level icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Center(
                  child: Text(
                    _levelEmoji(level),
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (desc != null && desc.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        desc,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        // Level badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _levelLabel(level),
                            style: GoogleFonts.inter(
                              color: color,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Lesson count
                        Text(
                          lessonCount > 0
                              ? '$lessonCount bài học'
                              : 'Chưa có bài',
                          style: GoogleFonts.inter(
                            color:
                                lessonCount > 0
                                    ? const Color(0xFF6366F1)
                                    : Colors.white30,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Trailing
              if (isGenerating)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF6366F1),
                  ),
                )
              else if (lessonCount > 0)
                const Icon(
                  Icons.play_circle_filled,
                  color: Color(0xFF6366F1),
                  size: 24,
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '✨ Tạo AI',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF6366F1),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Level Chip (for add dialog) ──────────────────────────────────────────────
class _LevelChip extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final VoidCallback onTap;

  const _LevelChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color:
                isSelected
                    ? const Color(0xFF6366F1).withOpacity(0.2)
                    : const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color:
                  isSelected
                      ? const Color(0xFF6366F1)
                      : const Color(0xFF334155),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: isSelected ? Colors.white : Colors.white54,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
