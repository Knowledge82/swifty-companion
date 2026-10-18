import 'package:flutter/material.dart';
import 'package:swifty_companion/l10n/app_strings.dart';
import 'package:swifty_companion/ui/steampunk/steampunk_theme.dart';

/// Обёртка для тестов виджетов: тот же набор языков и делегатов, что в
/// приложении. Язык задаём явно, иначе тестовая среда выберет английский
/// и тексты в проверках зависели бы от настроек машины.
///
/// [textScale] имитирует крупный системный шрифт.
Widget testApp(
  Widget home, {
  Locale locale = const Locale('es'),
  double textScale = 1,
}) {
  return MaterialApp(
    // Настоящая тема приложения: тесты видят то же оформление, что и пользователь.
    theme: buildSteampunkTheme(),
    locale: locale,
    localizationsDelegates: AppStrings.localizationsDelegates,
    supportedLocales: AppStrings.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
      ),
      child: child!,
    ),
    home: home,
  );
}
