import 'package:flutter/material.dart';

class AppTheme {

  static const Color primary = Color(0xFF6C5CE7);
  static const Color secondary = Color(0xFFA29BFE);

  static const LinearGradient backgroundGradient =
      LinearGradient(
    colors: [
      Color(0xFF6C5CE7),
      Color(0xFFA29BFE),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static ThemeData theme = ThemeData(

    primaryColor: primary,

    scaffoldBackgroundColor: Colors.white,

    appBarTheme: const AppBarTheme(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
    ),

    floatingActionButtonTheme:
        const FloatingActionButtonThemeData(
      backgroundColor: primary,
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
    ),

    cardTheme: const CardTheme(
      elevation: 3,
      margin: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.all(Radius.circular(12)),
      ),
    ),
  );
}