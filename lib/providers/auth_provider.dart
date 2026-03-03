import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  User? _user;
  String _role = 'user';

  User? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get isAdmin => _role == 'admin';
  String get role => _role;

  AuthProvider() {
    _user = _supabase.auth.currentUser;
    if (_user != null) _loadRole();

    _supabase.auth.onAuthStateChange.listen((data) {
      _user = data.session?.user;
      if (_user != null) {
        _loadRole();
      } else {
        _role = 'user';
      }
      notifyListeners();
    });
  }

  Future<void> _loadRole() async {
    try {
      final res =
          await _supabase
              .from('profiles')
              .select('role')
              .eq('id', _user!.id)
              .maybeSingle();

      _role = res?['role'] as String? ?? 'user';
      notifyListeners();
    } catch (_) {
      _role = 'user';
    }
  }

  Future<void> signInWithEmail(String email, String password) async {
    await _supabase.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signUpWithEmail(
    String email,
    String password, [
    String? fullName,
  ]) async {
    await _supabase.auth.signUp(
      email: email,
      password: password,
      data: fullName != null ? {'full_name': fullName} : null,
    );
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
    _role = 'user';
  }
}
