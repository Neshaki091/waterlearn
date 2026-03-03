import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'providers/auth_provider.dart';
import 'providers/quiz_session_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://euvpfmshowfdssfixtpz.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImV1dnBmbXNob3dmZHNzZml4dHB6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE5MzU4MTQsImV4cCI6MjA4NzUxMTgxNH0.0rBVj_b2aZ45VwJcHXKnHudBH8i4ORps-BQBimTiwD4',
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => QuizSessionProvider()),
      ],
      child: const WaterLearnApp(),
    ),
  );
}

class WaterLearnApp extends StatelessWidget {
  const WaterLearnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WaterLearn',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.interTextTheme(
          ThemeData(brightness: Brightness.dark).textTheme,
        ),
        useMaterial3: true,
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.fixed,
        ),
      ),
      home: const _AuthGate(),
    );
  }
}

/// AuthGate: Nếu đã đăng nhập → HomeScreen, chưa → AuthScreen.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    return authProvider.isLoggedIn ? const HomeScreen() : const AuthScreen();
  }
}
