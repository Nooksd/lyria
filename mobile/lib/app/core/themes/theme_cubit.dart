import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ThemeCubit extends Cubit<ThemeData> {
  ThemeCubit() : super(_defaultTheme);

  static final ThemeData _defaultTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: "NooplaRegular",
    scaffoldBackgroundColor: const Color(0xFF171717),
    colorScheme: const ColorScheme.light(
      primary: Colors.white,
      onPrimary: Color(0xFF171717),
      primaryContainer: Color(0xFF171717),
      secondary: Colors.white,
      error: Color(0xFFFDD9D7),
      onError: Color(0xFFF44336),
      onSurface: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Colors.white,
      contentTextStyle: const TextStyle(
        color: Color(0xFF171717),
      ),
    ),
    textTheme: const TextTheme(
      titleLarge: TextStyle(),
      titleMedium: TextStyle(),
      titleSmall: TextStyle(),
      bodyLarge: TextStyle(),
      bodyMedium: TextStyle(),
      bodySmall: TextStyle(),
    ).apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      hintStyle: TextStyle(color: Colors.white),
    ),
    iconTheme: const IconThemeData(color: Colors.white),
    primaryIconTheme: const IconThemeData(color: Colors.white),
  );

  void updatePrimaryColor(Color newColor) {
    emit(state.copyWith(
      colorScheme: state.colorScheme.copyWith(
        primary: newColor,
        onPrimary:
            newColor == Colors.white ? const Color(0xFF171717) : Colors.white,
      ),
      textTheme: state.textTheme.apply(
        bodyColor: newColor,
        displayColor: newColor,
      ),
      snackBarTheme: state.snackBarTheme.copyWith(
        backgroundColor: newColor,
        contentTextStyle: TextStyle(color: const Color(0xFF171717)),
      ),
      inputDecorationTheme: state.inputDecorationTheme.copyWith(
        hintStyle: TextStyle(color: newColor),
      ),
      iconTheme: state.iconTheme.copyWith(color: newColor),
      primaryIconTheme: state.primaryIconTheme.copyWith(color: newColor),
    ));
  }
}
