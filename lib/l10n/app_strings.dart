import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/api_exception.dart';
import '../core/login.dart';
import '../models/project_category.dart';
import 'app_strings_en.dart';
import 'app_strings_es.dart';

/// Все тексты интерфейса. Это абстрактный «словарь»: у него есть по одному
/// геттеру на каждую фразу, а сами фразы лежат в двух наследниках
/// (`AppStringsEs`, `AppStringsEn`).
///
/// Если добавить фразу сюда и забыть перевести на один из языков,
/// проект не соберётся: компилятор требует реализовать все геттеры.
abstract class AppStrings {
  const AppStrings();

  /// Первый язык в списке это язык по умолчанию: если язык телефона
  /// не испанский и не английский, Flutter выберет испанский.
  static const List<Locale> supportedLocales = [Locale('es'), Locale('en')];

  static const LocalizationsDelegate<AppStrings> delegate =
      _AppStringsDelegate();

  /// Наш словарь + встроенные переводы самого Flutter (подсказка «Назад»,
  /// названия месяцев, контекстное меню копирования и т. п.).
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  static AppStrings of(BuildContext context) {
    final strings = Localizations.of<AppStrings>(context, AppStrings);
    assert(
      strings != null,
      'AppStrings.delegate не подключён к MaterialApp (localizationsDelegates)',
    );
    return strings!;
  }

  static AppStrings forLocale(Locale locale) =>
      locale.languageCode == 'en' ? const AppStringsEn() : const AppStringsEs();

  // Общее
  String get appTitle;

  // Экран поиска
  String get loginLabel;
  String get searchButton;
  String get loginEmptyError;
  String get loginInvalidError;

  // Ошибки запроса
  String get networkError;
  String get timeoutError;
  String get authError;
  String get notFoundError;
  String get rateLimitError;
  String retryAfterHint(int seconds);
  String get serverError;
  String get unexpectedError;

  // Экран профиля
  String get emailLabel;
  String get phoneLabel;
  String get locationLabel;
  String get onlineLabel;
  String get onlineOn;
  String get onlineOff;
  String get levelLabel;
  String get walletLabel;
  String get correctionPointsLabel;

  // Скиллы и проекты
  String get skillsTitle;
  String get skillsEmpty;
  String skillsFormulaNote(int maxLevel);
  String get projectsTitle;
  String get projectsEmpty;
  String get projectsOuterCore;
  String get projectsCommonCore;
  String get projectsPiscine;
  String get projectsPiscineReloaded;
  String get projectPassed;
  String get projectFailed;
  String get projectUnknown;
  String get unnamed;

  // Экран ошибки конфигурации
  String get configErrorTitle;
  String configMissing(List<String> keys);
  String get configUnreadable;
  String get configHint;

  /// Название раздела проектов. `switch` по enum исчерпывающий.
  String projectCategoryTitle(ProjectCategory category) => switch (category) {
        ProjectCategory.outerCore => projectsOuterCore,
        ProjectCategory.commonCore => projectsCommonCore,
        ProjectCategory.piscine => projectsPiscine,
        ProjectCategory.piscineReloaded => projectsPiscineReloaded,
      };

  /// Текст проблемы с логином. `switch` по enum исчерпывающий.
  String loginProblemText(LoginProblem problem) => switch (problem) {
        LoginProblem.empty => loginEmptyError,
        LoginProblem.invalidChars => loginInvalidError,
      };

  /// Текст ошибки запроса. `switch` по sealed-классу исчерпывающий:
  /// новый вид ошибки без перевода не соберётся.
  String errorText(ApiException error) => switch (error) {
        NetworkException(isTimeout: true) => timeoutError,
        NetworkException() => networkError,
        AuthException() => authError,
        NotFoundException() => notFoundError,
        RateLimitException(:final retryAfter) => retryAfter == null
            ? rateLimitError
            : '$rateLimitError ${retryAfterHint(retryAfter.inSeconds)}',
        ServerException() => serverError,
        UnexpectedResponseException() => unexpectedError,
      };
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'es' || locale.languageCode == 'en';

  /// `SynchronousFuture`: тексты у нас в коде, ждать нечего, и первый кадр
  /// рисуется сразу, без мигания.
  @override
  Future<AppStrings> load(Locale locale) =>
      SynchronousFuture<AppStrings>(AppStrings.forLocale(locale));

  @override
  bool shouldReload(_AppStringsDelegate old) => false;
}
