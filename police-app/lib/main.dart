import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // SystemChrome APIs are mobile-only — skip on web to avoid silent crash
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
  }

  runApp(const RakshakPoliceApp());
}

// ── Phone frame — centers a 390×844 phone shell on web ───────────────────────
class PhoneFrame extends StatelessWidget {
  final Widget child;
  const PhoneFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Container(
          width: 390,
          height: 844,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(44),
            boxShadow: const [
              BoxShadow(
                color: Colors.black87,
                blurRadius: 60,
                spreadRadius: 20,
              ),
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: child,
        ),
      ),
    );
  }
}

class RakshakPoliceApp extends StatelessWidget {
  const RakshakPoliceApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0d1117),
      colorScheme: const ColorScheme.dark(
        primary:   Color(0xFF00d4b4),
        secondary: Color(0xFF00d4b4),
        surface:   Color(0xFF161b22),
        error:     Color(0xFFef4444),
      ),
      fontFamily: 'Inter',
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF161b22),
        foregroundColor: Color(0xFFf0f6fc),
        elevation: 0,
        titleTextStyle: TextStyle(
          color: Color(0xFFf0f6fc),
          fontSize: 16,
          fontWeight: FontWeight.w700,
          fontFamily: 'Inter',
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Color(0xFF161b22),
        contentTextStyle: TextStyle(color: Color(0xFFf0f6fc)),
      ),
      useMaterial3: true,
    );

    // On web: wrap in a phone frame so it looks like a real device
    // On mobile: run full-screen as normal
    if (kIsWeb) {
      return MaterialApp(
        title: 'Rakshak Police',
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: PhoneFrame(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            home: const LoginScreen(),
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'Rakshak Police',
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: const LoginScreen(),
    );
  }
}
