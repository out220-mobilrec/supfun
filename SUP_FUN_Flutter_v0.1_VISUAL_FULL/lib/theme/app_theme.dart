// App theme configuration for SUP FUN
import 'package:flutter/material.dart';

class AppTheme {
  // Brand colors - dark navy (matches splash screen)
  static const Color primaryColor = Color(0xFF1A4A6E);
  static const Color primaryLight = Color(0xFF2E6A92);
  static const Color primaryDark = Color(0xFF0F2E45);
  static const Color accentColor = Color(0xFF00A6A6); // бирюзовый как вторичный акцент
  static const Color secondaryColor = Color(0xFFFFB400);
  static const Color backgroundColor = Color(0xFFF4F8F7);
  static const Color cardColor = Colors.white;
  static const Color textPrimary = Color(0xFF0F2E45); // matches primaryDark
  static const Color textSecondary = Color(0xFF6B7B8C);
  static const Color borderColor = Color(0xFFE0E6E9);
  static const Color successColor = Color(0xFF4CAF50);
  static const Color warningColor = Color(0xFFFF9800);
  static const Color errorColor = Color(0xFFF44336);

  // Weather icons colors
  static const Color sunnyColor = Color(0xFFFFB400);
  static const Color cloudyColor = Color(0xFF90A4AE);
  static const Color rainyColor = Color(0xFF42A5F5);

  // Sizes
  static const double padding = 16.0;
  static const double radius = 16.0;
  static const double radiusSmall = 8.0;
  static const double radiusLarge = 24.0;

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: backgroundColor,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
      primary: primaryColor,
      secondary: secondaryColor,
    ),
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: textPrimary,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: primaryColor,
      unselectedItemColor: textSecondary,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSmall),
        borderSide: const BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSmall),
        borderSide: const BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSmall),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
    ),
  );
}
