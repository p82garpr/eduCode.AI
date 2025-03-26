import 'package:flutter/material.dart';

class AppTheme {
  // Definir los colores para nuestra aplicación
  static const Color primaryBlue = Color(0xFF1565C0);
  static const Color lightBlue = Color(0xFFBBDEFB);
  static const Color mediumBlue = Color(0xFF64B5F6);
  static const Color darkBlue = Color(0xFF0D47A1);

  static ThemeData get lightTheme {
    const seedColor = primaryBlue;
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.light,
        background: Colors.transparent, // Fondo transparente para permitir el gradiente
      ),
      scaffoldBackgroundColor: Colors.transparent, // Fondo transparente para el scaffold
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    const seedColor = primaryBlue;
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.dark,
        background: Colors.transparent, // Fondo transparente para permitir el gradiente
      ),
      scaffoldBackgroundColor: Colors.transparent, // Fondo transparente para el scaffold
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }
} 