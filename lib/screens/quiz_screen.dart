import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/course_models.dart';
import '../providers/quiz_session_provider.dart';
import '../widgets/user_status_bar.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen>
    with SingleTickerProviderStateMixin {
  String? _selectedAnswer;
  int? _selectedLine; // Dùng cho find_error
  bool _answered = false;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 12).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  // ── Xử lý đáp án multiple_choice / true_false / fix_syntax ──
  void _onSelectAnswer(String option) {
    if (_answered) return;
    setState(() {
      _selectedAnswer = option;
      _answered = true;
    });

    final session = context.read<QuizSessionProvider>();
    final quiz = session.currentQuiz!;
    final isCorrect = option == quiz.answer;

    if (!isCorrect) {
      session.loseHeart();
      _shakeController.forward(from: 0);
    } else {
      session.addScore(quiz.xpReward);
    }

    _showResultSheet(isCorrect, quiz);
  }

  // ── Xử lý đáp án find_error (chọn dòng code) ──
  void _onSelectLine(int lineIndex) {
    if (_answered) return;
    setState(() {
      _selectedLine = lineIndex;
      _answered = true;
    });

    final session = context.read<QuizSessionProvider>();
    final quiz = session.currentQuiz!;
    final correctLine = int.tryParse(quiz.answer) ?? quiz.errorLine ?? -1;
    final isCorrect = lineIndex == correctLine;

    if (!isCorrect) {
      session.loseHeart();
      _shakeController.forward(from: 0);
    } else {
      session.addScore(quiz.xpReward);
    }

    _showResultSheet(isCorrect, quiz);
  }

  void _showResultSheet(bool isCorrect, Quiz quiz) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder:
          (_) => _ResultSheet(
            isCorrect: isCorrect,
            quiz: quiz,
            selectedAnswer: _selectedAnswer,
            selectedLine: _selectedLine,
            onNext: () {
              Navigator.pop(context);
              _proceed();
            },
          ),
    );
  }

  void _proceed() {
    final session = context.read<QuizSessionProvider>();

    if (session.isGameOver) {
      _showGameOver();
      return;
    }

    session.nextQuiz();

    if (session.isFinished) {
      _showFinished();
      return;
    }

    setState(() {
      _selectedAnswer = null;
      _selectedLine = null;
      _answered = false;
    });
  }

  void _showGameOver() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => _EndDialog(
            title: '💔 Hết tim rồi!',
            subtitle:
                'Bạn đã tiêu hết ${QuizSessionProvider.maxHearts} trái tim.',
            color: Colors.redAccent,
            score: context.read<QuizSessionProvider>().score,
            correctCount: context.read<QuizSessionProvider>().correctCount,
            wrongCount: context.read<QuizSessionProvider>().wrongCount,
            onRetry: () {
              Navigator.pop(context);
              context.read<QuizSessionProvider>().reset();
              setState(() {
                _selectedAnswer = null;
                _selectedLine = null;
                _answered = false;
              });
            },
            onExit: () => Navigator.of(context).popUntil((r) => r.isFirst),
          ),
    );
  }

  void _showFinished() {
    final session = context.read<QuizSessionProvider>();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => _EndDialog(
            title: '🏆 Hoàn thành!',
            subtitle: 'Bạn đã trả lời hết tất cả câu hỏi.',
            color: const Color(0xFF10B981),
            score: session.score,
            correctCount: session.correctCount,
            wrongCount: session.wrongCount,
            onRetry: () {
              Navigator.pop(context);
              session.reset();
              setState(() {
                _selectedAnswer = null;
                _selectedLine = null;
                _answered = false;
              });
            },
            onExit: () => Navigator.of(context).popUntil((r) => r.isFirst),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<QuizSessionProvider>(
      builder: (context, session, _) {
        final quiz = session.currentQuiz;

        if (quiz == null) {
          return const Scaffold(
            backgroundColor: Color(0xFF0F172A),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final total = session.quizzes.length;
        final current = session.currentQuizIndex;
        final progress = total > 0 ? (current / total) : 0.0;

        return Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0F172A),
            elevation: 0,
            automaticallyImplyLeading: false,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white54),
              onPressed: () => Navigator.pop(context),
            ),
            title: _ProgressBar(
              progress: progress,
              current: current,
              total: total,
            ),
            actions: [UserStatusBar(hearts: session.hearts, xp: session.score)],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  // Quiz type badge
                  Center(child: _QuizTypeBadge(quizType: quiz.quizType)),
                  const SizedBox(height: 16),
                  // Question card với shake animation
                  AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder:
                        (context, child) => Transform.translate(
                          offset: Offset(
                            _shakeController.isAnimating
                                ? _shakeAnimation.value *
                                    ((_shakeController.value * 10)
                                            .round()
                                            .isEven
                                        ? 1
                                        : -1)
                                : 0,
                            0,
                          ),
                          child: child,
                        ),
                    child: _QuestionCard(question: quiz.question),
                  ),
                  const SizedBox(height: 20),
                  // Body phân nhánh theo quiz_type
                  Expanded(child: _buildQuizBody(quiz)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuizBody(Quiz quiz) {
    switch (quiz.quizType) {
      case QuizType.findError:
        return _FindErrorBody(
          buggyCode: quiz.buggyCode ?? '',
          codeLanguage: quiz.codeLanguage,
          selectedLine: _selectedLine,
          correctLine: int.tryParse(quiz.answer) ?? quiz.errorLine ?? -1,
          answered: _answered,
          onSelectLine: _onSelectLine,
        );

      case QuizType.fixSyntax:
        return _FixSyntaxBody(
          buggyCode: quiz.buggyCode ?? '',
          options: quiz.options,
          codeLanguage: quiz.codeLanguage,
          selectedAnswer: _selectedAnswer,
          correctAnswer: quiz.answer,
          answered: _answered,
          onSelect: _onSelectAnswer,
        );

      default: // multiple_choice, true_false, fill_blank, code_output
        return SingleChildScrollView(
          child: Column(
            children:
                quiz.options
                    .map(
                      (option) => _AnswerButton(
                        option: option,
                        selectedAnswer: _selectedAnswer,
                        correctAnswer: quiz.answer,
                        answered: _answered,
                        onTap: () => _onSelectAnswer(option),
                      ),
                    )
                    .toList(),
          ),
        );
    }
  }
}

// ─── Quiz Type Badge ──────────────────────────────────────────────────────────
class _QuizTypeBadge extends StatelessWidget {
  final QuizType quizType;
  const _QuizTypeBadge({required this.quizType});

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;
    String emoji;

    switch (quizType) {
      case QuizType.findError:
        label = 'Tìm lỗi sai';
        color = const Color(0xFFF59E0B);
        emoji = '🔍';
        break;
      case QuizType.fixSyntax:
        label = 'Sửa lỗi code';
        color = const Color(0xFFEF4444);
        emoji = '🔧';
        break;
      case QuizType.trueFalse:
        label = 'Đúng / Sai';
        color = const Color(0xFF06B6D4);
        emoji = '✅';
        break;
      case QuizType.codeOutput:
        label = 'Đoán kết quả';
        color = const Color(0xFF8B5CF6);
        emoji = '💻';
        break;
      default:
        label = 'Trắc nghiệm';
        color = const Color(0xFF6366F1);
        emoji = '📝';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Find Error Body ──────────────────────────────────────────────────────────
class _FindErrorBody extends StatelessWidget {
  final String buggyCode;
  final String codeLanguage;
  final int? selectedLine;
  final int correctLine;
  final bool answered;
  final void Function(int) onSelectLine;

  const _FindErrorBody({
    required this.buggyCode,
    required this.codeLanguage,
    required this.selectedLine,
    required this.correctLine,
    required this.answered,
    required this.onSelectLine,
  });

  @override
  Widget build(BuildContext context) {
    final lines = buggyCode.split('\n');

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '👆 Chạm vào dòng code có lỗi:',
              style: GoogleFonts.inter(
                color: Colors.white60,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // Code viewer
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0D1117),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF30363D)),
            ),
            child: Column(
              children: [
                // Language tab
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFF161B22),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(13),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.code, color: Colors.white38, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        codeLanguage,
                        style: GoogleFonts.jetBrainsMono(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                // Code lines
                ...List.generate(lines.length, (i) {
                  Color bgColor = Colors.transparent;
                  Color lineNumColor = Colors.white24;

                  if (answered) {
                    if (i == correctLine) {
                      bgColor =
                          selectedLine == correctLine
                              ? const Color(0xFF10B981).withOpacity(0.15)
                              : const Color(0xFF10B981).withOpacity(0.1);
                      lineNumColor = const Color(0xFF10B981);
                    }
                    if (selectedLine == i && i != correctLine) {
                      bgColor = Colors.redAccent.withOpacity(0.15);
                      lineNumColor = Colors.redAccent;
                    }
                  } else if (selectedLine == i) {
                    bgColor = const Color(0xFFF59E0B).withOpacity(0.12);
                    lineNumColor = const Color(0xFFF59E0B);
                  }

                  return InkWell(
                    onTap: answered ? null : () => onSelectLine(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      color: bgColor,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 24,
                            child: Text(
                              '${i + 1}',
                              style: GoogleFonts.jetBrainsMono(
                                color: lineNumColor,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              lines[i],
                              style: GoogleFonts.jetBrainsMono(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                          ),
                          if (answered && i == correctLine)
                            const Icon(
                              Icons.error,
                              color: Color(0xFFF59E0B),
                              size: 16,
                            ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
              ],
            ),
          ),
          // Submit button (cho find_error khi đã chọn dòng nhưng chưa answered)
          if (!answered && selectedLine != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => onSelectLine(selectedLine!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Xác nhận dòng ${selectedLine! + 1}',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Fix Syntax Body ──────────────────────────────────────────────────────────
class _FixSyntaxBody extends StatelessWidget {
  final String buggyCode;
  final List<String> options;
  final String codeLanguage;
  final String? selectedAnswer;
  final String correctAnswer;
  final bool answered;
  final void Function(String) onSelect;

  const _FixSyntaxBody({
    required this.buggyCode,
    required this.options,
    required this.codeLanguage,
    required this.selectedAnswer,
    required this.correctAnswer,
    required this.answered,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Buggy code display
          Text(
            '❌ Code bị lỗi:',
            style: GoogleFonts.inter(
              color: Colors.redAccent.withOpacity(0.8),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1117),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
            ),
            child: Text(
              buggyCode,
              style: GoogleFonts.jetBrainsMono(
                color: Colors.white70,
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '🔧 Chọn phương án sửa đúng:',
            style: GoogleFonts.inter(
              color: Colors.white60,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          // Options as code blocks
          ...options.map((option) {
            final optionLetter =
                option.length > 2 ? option.substring(0, 2) : option;
            return _CodeOptionCard(
              option: option,
              optionLetter: optionLetter,
              selectedAnswer: selectedAnswer,
              correctAnswer: correctAnswer,
              answered: answered,
              onTap: () => onSelect(option),
            );
          }),
        ],
      ),
    );
  }
}

class _CodeOptionCard extends StatelessWidget {
  final String option;
  final String optionLetter;
  final String? selectedAnswer;
  final String correctAnswer;
  final bool answered;
  final VoidCallback onTap;

  const _CodeOptionCard({
    required this.option,
    required this.optionLetter,
    required this.selectedAnswer,
    required this.correctAnswer,
    required this.answered,
    required this.onTap,
  });

  Color _getBorderColor() {
    if (!answered) return const Color(0xFF334155);
    if (option == correctAnswer) return const Color(0xFF10B981);
    if (option == selectedAnswer) return Colors.redAccent;
    return const Color(0xFF334155);
  }

  Color _getBg() {
    if (!answered) return const Color(0xFF1E293B);
    if (option == correctAnswer)
      return const Color(0xFF10B981).withOpacity(0.1);
    if (option == selectedAnswer) return Colors.redAccent.withOpacity(0.1);
    return const Color(0xFF1E293B);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: answered ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _getBg(),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _getBorderColor(), width: 2),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  option,
                  style: GoogleFonts.jetBrainsMono(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ),
              if (answered && option == correctAnswer)
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFF10B981),
                  size: 20,
                ),
              if (answered &&
                  option == selectedAnswer &&
                  option != correctAnswer)
                const Icon(Icons.cancel, color: Colors.redAccent, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Progress Bar ─────────────────────────────────────────────────────────────
class _ProgressBar extends StatelessWidget {
  final double progress;
  final int current;
  final int total;

  const _ProgressBar({
    required this.progress,
    required this.current,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: const Color(0xFF1E293B),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF6366F1)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$current/$total',
          style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }
}

// ─── Question Card ────────────────────────────────────────────────────────────
class _QuestionCard extends StatelessWidget {
  final String question;

  const _QuestionCard({required this.question});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E293B), Color(0xFF0F2744)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF334155)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        question,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          height: 1.5,
        ),
      ),
    );
  }
}

// ─── Answer Button (for multiple_choice) ──────────────────────────────────────
class _AnswerButton extends StatelessWidget {
  final String option;
  final String? selectedAnswer;
  final String correctAnswer;
  final bool answered;
  final VoidCallback onTap;

  const _AnswerButton({
    required this.option,
    required this.selectedAnswer,
    required this.correctAnswer,
    required this.answered,
    required this.onTap,
  });

  Color _getBorderColor() {
    if (!answered) return const Color(0xFF334155);
    if (option == correctAnswer) return const Color(0xFF10B981);
    if (option == selectedAnswer) return Colors.redAccent;
    return const Color(0xFF334155);
  }

  Color _getBackgroundColor() {
    if (!answered) return const Color(0xFF1E293B);
    if (option == correctAnswer)
      return const Color(0xFF10B981).withOpacity(0.15);
    if (option == selectedAnswer) return Colors.redAccent.withOpacity(0.15);
    return const Color(0xFF1E293B);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _getBackgroundColor(),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _getBorderColor(), width: 2),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: answered ? null : onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      option,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (answered && option == correctAnswer)
                    const Icon(Icons.check_circle, color: Color(0xFF10B981)),
                  if (answered &&
                      option == selectedAnswer &&
                      option != correctAnswer)
                    const Icon(Icons.cancel, color: Colors.redAccent),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Result Bottom Sheet ──────────────────────────────────────────────────────
class _ResultSheet extends StatelessWidget {
  final bool isCorrect;
  final Quiz quiz;
  final String? selectedAnswer;
  final int? selectedLine;
  final VoidCallback onNext;

  const _ResultSheet({
    required this.isCorrect,
    required this.quiz,
    required this.selectedAnswer,
    required this.selectedLine,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final color = isCorrect ? const Color(0xFF10B981) : Colors.redAccent;
    final emoji = isCorrect ? '🎉' : '😅';
    final title = isCorrect ? 'Chính xác!' : 'Sai rồi!';
    final showDiff =
        quiz.quizType == QuizType.fixSyntax &&
        quiz.buggyCode != null &&
        quiz.fixedCode != null;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: color, width: 3)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          color: color,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '+${quiz.xpReward} XP',
                        style: GoogleFonts.inter(
                          color:
                              isCorrect
                                  ? const Color(0xFFFBBF24)
                                  : Colors.white30,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Đáp án đúng cho find_error
            if (!isCorrect && quiz.quizType == QuizType.findError) ...[
              Text(
                '✅ Dòng lỗi đúng: dòng ${(int.tryParse(quiz.answer) ?? 0) + 1}',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Đáp án đúng cho multiple_choice / fix_syntax
            if (!isCorrect && quiz.quizType != QuizType.findError) ...[
              Text(
                '✅ Đáp án đúng:',
                style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                quiz.answer,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Before / After panel cho fix_syntax
            if (showDiff) ...[
              _BeforeAfterPanel(
                buggyCode: quiz.buggyCode!,
                fixedCode: quiz.fixedCode!,
                codeLanguage: quiz.codeLanguage,
              ),
              const SizedBox(height: 8),
            ],

            // Giải thích
            if (quiz.explanation != null && quiz.explanation!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('💡', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        quiz.explanation!,
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Next button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Tiếp theo →',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Before / After Panel ─────────────────────────────────────────────────────
class _BeforeAfterPanel extends StatelessWidget {
  final String buggyCode;
  final String fixedCode;
  final String codeLanguage;

  const _BeforeAfterPanel({
    required this.buggyCode,
    required this.fixedCode,
    required this.codeLanguage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Before
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.05),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(11),
                  bottomLeft: Radius.circular(11),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '❌ Trước',
                    style: GoogleFonts.inter(
                      color: Colors.redAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    buggyCode,
                    style: GoogleFonts.jetBrainsMono(
                      color: Colors.white60,
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(width: 1, color: const Color(0xFF30363D)),
          // After
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.05),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(11),
                  bottomRight: Radius.circular(11),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '✅ Sau',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF10B981),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    fixedCode,
                    style: GoogleFonts.jetBrainsMono(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── End Dialog ───────────────────────────────────────────────────────────────
class _EndDialog extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final int score;
  final int correctCount;
  final int wrongCount;
  final VoidCallback onRetry;
  final VoidCallback onExit;

  const _EndDialog({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.score,
    required this.correctCount,
    required this.wrongCount,
    required this.onRetry,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(
                color: color,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.white60, fontSize: 14),
            ),
            const SizedBox(height: 20),
            // Stats
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatColumn(
                    label: 'XP',
                    value: '$score',
                    color: const Color(0xFFFBBF24),
                  ),
                  Container(
                    width: 1,
                    height: 36,
                    color: const Color(0xFF334155),
                  ),
                  _StatColumn(
                    label: 'Đúng',
                    value: '$correctCount',
                    color: const Color(0xFF10B981),
                  ),
                  Container(
                    width: 1,
                    height: 36,
                    color: const Color(0xFF334155),
                  ),
                  _StatColumn(
                    label: 'Sai',
                    value: '$wrongCount',
                    color: Colors.redAccent,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onExit,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white54,
                      side: const BorderSide(color: Color(0xFF334155)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Thoát',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onRetry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Thử lại',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatColumn({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
        ),
      ],
    );
  }
}
