import 'package:flutter/material.dart';

// Палитра «стимпанк»: латунь, медь, тёмная кожа, пергамент, патина.
// Все цвета собраны здесь, чтобы весь вид приложения менялся в одном месте.

const Color brass = Color(0xFFC8A04A);
const Color copper = Color(0xFFB87333);
const Color leather = Color(0xFF2A1C12);
const Color leatherDeep = Color(0xFF1A110B);
const Color leatherLight = Color(0xFF3A281A);
const Color parchment = Color(0xFFEADFC4);
const Color verdigris = Color(0xFF6FB39C);
const Color rust = Color(0xFFE0745A);
const Color mutedBrass = Color(0xFFA8946F);

/// Тёмная цветовая схема. Контраст текста к фону проверяется тестом
/// (`steampunk_test.dart`): основной текст не ниже 7:1, остальной не ниже 4.5:1.
const ColorScheme steampunkColors = ColorScheme(
  brightness: Brightness.dark,
  primary: brass,
  onPrimary: leatherDeep,
  secondary: copper,
  onSecondary: leatherDeep,
  tertiary: verdigris,
  onTertiary: leatherDeep,
  error: rust,
  onError: leatherDeep,
  errorContainer: Color(0xFF4A1F16),
  onErrorContainer: Color(0xFFFFDAD2),
  surface: leather,
  onSurface: parchment,
  onSurfaceVariant: mutedBrass,
  outline: mutedBrass,
  outlineVariant: Color(0xFF5A4630),
  surfaceContainerHighest: leatherLight,
);

/// Шрифт с засечками, который есть в системе Android (`serif`), чтобы не
/// добавлять в проект файлы шрифтов и сетевую загрузку.
const String _serif = 'serif';

/// Тема приложения. Собирается одним вызовом конструктора `ThemeData`
/// (не `copyWith`): так меньше шансов споткнуться об изменения типов
/// компонентных тем между версиями Flutter.
///
/// Оформление поля ввода сюда намеренно не входит: оно задаётся прямо
/// у поля через [steampunkInputDecoration].
ThemeData buildSteampunkTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: steampunkColors,
    fontFamily: _serif,
    scaffoldBackgroundColor: leatherDeep,
    appBarTheme: const AppBarTheme(
      backgroundColor: leatherDeep,
      foregroundColor: brass,
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      shape: Border(bottom: BorderSide(color: brass, width: 2)),
      titleTextStyle: TextStyle(
        fontFamily: _serif,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: brass,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: brass,
        foregroundColor: leatherDeep,
        disabledBackgroundColor: const Color(0xFF5A4630),
        disabledForegroundColor: mutedBrass,
        minimumSize: const Size.fromHeight(48),
        textStyle: const TextStyle(
          fontFamily: _serif,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: copper, width: 2),
        ),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: brass,
      linearTrackColor: Color(0xFF4A3828),
      circularTrackColor: Color(0xFF4A3828),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: brass,
      selectionColor: Color(0x66C8A04A),
      selectionHandleColor: brass,
    ),
  );
}

/// Оформление поля ввода: латунная рамка на тёмной коже.
InputDecoration steampunkInputDecoration({
  required String label,
  String? errorText,
}) {
  OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    labelText: label,
    errorText: errorText,
    filled: true,
    fillColor: leatherDeep,
    labelStyle: const TextStyle(color: mutedBrass),
    floatingLabelStyle: const TextStyle(color: brass),
    errorStyle: const TextStyle(color: rust),
    border: border(brass, 1.5),
    enabledBorder: border(copper, 1.5),
    focusedBorder: border(brass, 2.5),
    errorBorder: border(rust, 1.5),
    focusedErrorBorder: border(rust, 2.5),
    disabledBorder: border(const Color(0xFF5A4630), 1.5),
  );
}
