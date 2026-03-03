import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Model cho lớp học.
class AppClass {
  final String id;
  final String name;
  final String? description;
  final String level;

  const AppClass({
    required this.id,
    required this.name,
    this.description,
    required this.level,
  });

  factory AppClass.fromJson(Map<String, dynamic> json) => AppClass(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String?,
    level: json['level'] as String? ?? 'beginner',
  );

  Color get levelColor {
    switch (level) {
      case 'intermediate':
        return const Color(0xFFF59E0B);
      case 'advanced':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF10B981);
    }
  }

  String get levelLabel {
    switch (level) {
      case 'intermediate':
        return 'Trung cấp';
      case 'advanced':
        return 'Nâng cao';
      default:
        return 'Cơ bản';
    }
  }

  String get levelEmoji {
    switch (level) {
      case 'intermediate':
        return '🔥';
      case 'advanced':
        return '⚡';
      default:
        return '🌱';
    }
  }
}

/// Màn hình chọn lớp học trước khi vào học.
class ClassSelectorScreen extends StatefulWidget {
  const ClassSelectorScreen({super.key});

  @override
  State<ClassSelectorScreen> createState() => _ClassSelectorScreenState();
}

class _ClassSelectorScreenState extends State<ClassSelectorScreen> {
  final _supabase = Supabase.instance.client;
  List<AppClass> _classes = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    try {
      final data = await _supabase
          .from('classes')
          .select('id, name, description, level')
          .order('level');
      setState(() {
        _classes =
            (data as List)
                .map((c) => AppClass.fromJson(c as Map<String, dynamic>))
                .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📚 Chọn lớp học',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Chọn chủ đề bạn muốn học hôm nay',
                    style: GoogleFonts.inter(
                      color: Colors.white54,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child:
                  _loading
                      ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF6366F1),
                        ),
                      )
                      : _error != null
                      ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.redAccent,
                              size: 40,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Không thể tải danh sách lớp',
                              style: GoogleFonts.inter(color: Colors.white60),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _loading = true;
                                  _error = null;
                                });
                                _loadClasses();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6366F1),
                              ),
                              child: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      )
                      : RefreshIndicator(
                        onRefresh: _loadClasses,
                        color: const Color(0xFF6366F1),
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _classes.length,
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final cls = _classes[index];
                            return _ClassCard(
                              appClass: cls,
                              onTap: () => Navigator.pop(context, cls),
                            );
                          },
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Class Card ───────────────────────────────────────────────
class _ClassCard extends StatelessWidget {
  final AppClass appClass;
  final VoidCallback onTap;

  const _ClassCard({required this.appClass, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF334155)),
          boxShadow: [
            BoxShadow(
              color: appClass.levelColor.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Level icon
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: appClass.levelColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: appClass.levelColor.withOpacity(0.4)),
              ),
              child: Center(
                child: Text(
                  appClass.levelEmoji,
                  style: const TextStyle(fontSize: 26),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appClass.name,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (appClass.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      appClass.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: Colors.white54,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: appClass.levelColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: appClass.levelColor.withOpacity(0.5),
                      ),
                    ),
                    child: Text(
                      appClass.levelLabel,
                      style: GoogleFonts.inter(
                        color: appClass.levelColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white24,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
