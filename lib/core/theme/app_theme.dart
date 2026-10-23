import 'package:flutter/material.dart';

class AppTheme {
  // Paleta de colores base extraída de la imagen
  static const Color darkBurgundy = Color(0xFF5A0F24);
  static const Color raspberry = Color(0xFF8C2C45);
  static const Color dustyRose = Color(0xFFC68A8F);
  static const Color creamWhite = Color(0xFFF3EFE6);
  static const Color beige = Color(0xFFC9B8A6);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: creamWhite,
      colorScheme: const ColorScheme.light(
        primary: raspberry,
        onPrimary: Colors.white,
        primaryContainer: darkBurgundy,
        onPrimaryContainer: Colors.white,
        secondary: dustyRose,
        onSecondary: Colors.white,
        background: creamWhite,
        onBackground: darkBurgundy,
        surface: creamWhite,
        onSurface: darkBurgundy,
        surfaceVariant: beige,
        onSurfaceVariant: darkBurgundy,
      ),

      // Estilo global para la barra superior (AppBar)
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBurgundy,
        foregroundColor: creamWhite,
        centerTitle: true,
        elevation: 0,
      ),

      // Estilo global para botones principales
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: raspberry,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      // Estilo global para los campos de texto (TextFormField)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        labelStyle: const TextStyle(color: darkBurgundy),
        border: OutlineInputBorder(
          borderSide: const BorderSide(color: beige),
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: beige),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: raspberry, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.red),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}