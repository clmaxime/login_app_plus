import 'package:flutter/material.dart';
import 'controllers/auth_controller.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'services/auth_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LoginApp());
}

class LoginApp extends StatefulWidget {
  const LoginApp({super.key, this.authService});
  final AuthService? authService;
  @override
  State<LoginApp> createState() => _LoginAppState();
}

class _LoginAppState extends State<LoginApp> {
  AuthController? _auth;
  String? _configurationError;
  @override
  void initState() {
    super.initState();
    try {
      _auth = AuthController(widget.authService ?? AuthService())..restore();
    } on FormatException catch (e) {
      _configurationError = e.message;
    }
  }

  @override
  void dispose() {
    _auth?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF245E57));
    return MaterialApp(
      title: 'Espace • Connexion',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF3F5F2),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
      home: _auth == null
          ? Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _configurationError ?? 'Configuration indisponible',
                  ),
                ),
              ),
            )
          : AnimatedBuilder(
              animation: _auth!,
              builder: (context, _) {
                final auth = _auth!;
                if (auth.restoring) {
                  return const Scaffold(
                    body: Center(
                      child: CircularProgressIndicator(
                        semanticsLabel: 'Restauration de la session',
                      ),
                    ),
                  );
                }
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  child: auth.user == null
                      ? LoginScreen(key: const ValueKey('login'), auth: auth)
                      : ProfileScreen(
                          key: const ValueKey('profile'),
                          auth: auth,
                          user: auth.user!,
                        ),
                );
              },
            ),
    );
  }
}
