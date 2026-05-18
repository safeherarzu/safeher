import 'package:flutter/material.dart';

class AppTheme {
  /// Ana marka moru — arka planla uyumlu, biraz daha yumuşak lila-menekşe.
  static const Color brandPurple = Color(0xFF8B78D8);
  static const Color brandPink = Color(0xFFFF4DB8);
  static const Color brandBlue = Color(0xFF3D8DFF);
  static const Color bgDark = Color(0xFF352F4A);

  /// Uygulama geneli: önceki koyu neon mor yerine daha soft, tozlu lila geçişi.
  static const LinearGradient pageGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF4A4268),
      Color(0xFF7A6DA8),
      Color(0xFFB0A0D8),
      Color(0xFFD8CCEF),
    ],
  );

  static const LinearGradient actionGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      brandBlue,
      brandPurple,
      brandPink,
    ],
  );

  static ThemeData materialTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: brandPurple),
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: 0.1),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.15),
        hintStyle: const TextStyle(color: Colors.white70),
        labelStyle: const TextStyle(color: Colors.white70),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.15),
        selectedColor: brandPurple.withValues(alpha: 0.25),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        labelStyle: const TextStyle(color: Colors.white),
      ),
    );
  }
}

