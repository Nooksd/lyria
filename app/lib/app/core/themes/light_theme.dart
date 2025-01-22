import 'package:flutter/material.dart';

ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
  ),
  snackBarTheme: const SnackBarThemeData(
    backgroundColor: Color(0xFF2257A8),
  ),
  colorScheme: const ColorScheme.light(
    primary: Color(0xFF2257A8),
    primaryContainer: Color.fromRGBO(246, 248, 253, 1),
    primaryFixed: Color.fromRGBO(211, 221, 238, 1),
    onPrimary: Color(0xFF172242),
    secondary: Color(0xFFB0D159),
    error: Color(0xFFFDD9D7),
    onError: Color(0xFFF44336),
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF172242),
  ),
  textTheme: const TextTheme(
    titleLarge: TextStyle(
      color: Color(0xFF172242),
    ),
    titleMedium: TextStyle(
      color: Color(0xFF172242),
    ),
    titleSmall: TextStyle(
      color: Color(0xFF172242),
    ),
    bodyLarge: TextStyle(
      color: Color(0xFF172242),
    ),
    bodyMedium: TextStyle(
      color: Color(0xFF172242),
    ),
    bodySmall: TextStyle(
      color: Color(0xFF172242),
    ),
  ),
  inputDecorationTheme: const InputDecorationTheme(
    hintStyle: TextStyle(
      color: Color(0xFF172242),
    ),
  ),
  scaffoldBackgroundColor: Colors.white,
  fontFamily: "Inter",
  iconTheme: const IconThemeData(
    color: Color(0xFF2257A8),
  ),
  primaryIconTheme: const IconThemeData(
    color: Color(0xFF2257A8),
  ),
);