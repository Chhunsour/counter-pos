import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'config/env_config.dart';
import 'screens/dashboard_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  EnvConfig? config;
  String? configError;
  try {
    await dotenv.load(fileName: '.env');
    config = EnvConfig.fromDotEnv();
  } catch (error) {
    configError = error.toString().replaceFirst('FormatException: ', '');
  }

  runApp(BackendTestApp(config: config, configError: configError));
}

class BackendTestApp extends StatelessWidget {
  const BackendTestApp({
    required this.config,
    required this.configError,
    super.key,
  });

  final EnvConfig? config;
  final String? configError;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF17211D);
    const accent = Color(0xFFE86F3A);
    const canvas = Color(0xFFF3F1EC);

    return MaterialApp(
      title: 'Counter POS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.light,
          surface: const Color(0xFFFFFEFB),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: canvas,
        dividerColor: const Color(0xFFE4E0D7),
        textTheme: const TextTheme(
          displaySmall: TextStyle(
            color: ink,
            fontSize: 34,
            height: 1.05,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.2,
          ),
          headlineSmall: TextStyle(
            color: ink,
            fontSize: 24,
            height: 1.15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
          titleLarge: TextStyle(
            color: ink,
            fontSize: 19,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
          titleMedium: TextStyle(
            color: ink,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          bodyLarge: TextStyle(color: ink, fontSize: 15, height: 1.45),
          bodyMedium: TextStyle(color: Color(0xFF4E5954), height: 1.4),
          labelLarge: TextStyle(fontWeight: FontWeight.w700),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF8F6F1),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE1DDD4)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE1DDD4)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: accent, width: 1.5),
          ),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFFFFFEFB),
          margin: EdgeInsets.zero,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE5E1D8)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: ink,
            minimumSize: const Size(0, 46),
            side: const BorderSide(color: Color(0xFFD8D3C9)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
      home: DashboardScreen(config: config, configError: configError),
    );
  }
}
