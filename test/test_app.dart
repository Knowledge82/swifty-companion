import 'package:flutter/material.dart';
import 'package:swifty_companion/l10n/app_strings.dart';

/// Обёртка для тестов виджетов: тот же набор языков и делегатов, что в
/// приложении. Язык задаём явно, иначе тестовая среда выберет английский
/// и тексты в проверках зависели бы от настроек машины.
Widget testApp(Widget home, {Locale locale = const Locale('es')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppStrings.localizationsDelegates,
    supportedLocales: AppStrings.supportedLocales,
    home: home,
  );
}
