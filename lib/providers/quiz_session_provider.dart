import 'package:flutter/foundation.dart';
import '../models/course_models.dart';

/// Quản lý Hearts (tim), XP, và trạng thái quiz trong phiên chơi.
class QuizSessionProvider extends ChangeNotifier {
  static const int maxHearts = 5;

  int _hearts = maxHearts;
  int _score = 0;
  int _correctCount = 0;
  int _wrongCount = 0;
  int _currentQuizIndex = 0;

  int get hearts => _hearts;
  int get score => _score;
  int get correctCount => _correctCount;
  int get wrongCount => _wrongCount;
  int get currentQuizIndex => _currentQuizIndex;
  bool get isGameOver => _hearts <= 0;

  void loseHeart() {
    if (_hearts > 0) {
      _hearts--;
      _wrongCount++;
      notifyListeners();
    }
  }

  /// Cộng XP dựa theo xpReward của câu quiz.
  void addScore(int points) {
    _score += points;
    _correctCount++;
    notifyListeners();
  }

  void nextQuiz() {
    _currentQuizIndex++;
    notifyListeners();
  }

  void reset() {
    _hearts = maxHearts;
    _score = 0;
    _correctCount = 0;
    _wrongCount = 0;
    _currentQuizIndex = 0;
    notifyListeners();
  }

  // ── Quiz list ──
  List<Quiz> _quizzes = [];
  List<Quiz> get quizzes => _quizzes;

  void loadQuizzes(List<Quiz> quizzes) {
    _quizzes = quizzes;
    _currentQuizIndex = 0;
    notifyListeners();
  }

  Quiz? get currentQuiz =>
      _currentQuizIndex < _quizzes.length ? _quizzes[_currentQuizIndex] : null;

  bool get isFinished => _currentQuizIndex >= _quizzes.length;
}
