import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../core/api_exception.dart';
import '../core/login.dart';
import '../models/project_category.dart';
import '../models/project_section.dart';
import 'app_strings_en.dart';
import 'app_strings_es.dart';

/// All interface texts. This is an abstract "dictionary": it has one getter per
/// phrase, and the phrases themselves live in two subclasses (`AppStringsEs`,
/// `AppStringsEn`).
///
/// If you add a phrase here and forget to translate it into one of the
/// languages, the project will not build: the compiler requires all getters to
/// be implemented.
abstract class AppStrings {
  const AppStrings();

  /// The first language in the list is the default one: if the phone language
  /// is neither Spanish nor English, Flutter picks Spanish.
  static const List<Locale> supportedLocales = [Locale('es'), Locale('en')];

  static const LocalizationsDelegate<AppStrings> delegate =
      _AppStringsDelegate();

  /// Our dictionary + the built-in translations of the Material, Cupertino and
  /// base widgets (the "Back" tooltip, month names, the copy context menu,
  /// etc.). Since Flutter 3.50 the last three come as one list,
  /// `GlobalMaterialLocalizations.delegates`, from the `material_ui` package
  /// (the old per-library delegates are deprecated, see docs/17).
  ///
  /// `final` and not `const`: we have not verified that the list from the
  /// package is a compile-time constant, and a `final` list works either way.
  static final List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    delegate,
    ...GlobalMaterialLocalizations.delegates,
  ];

  static AppStrings of(BuildContext context) {
    final strings = Localizations.of<AppStrings>(context, AppStrings);
    assert(
      strings != null,
      'AppStrings.delegate is not connected to MaterialApp (localizationsDelegates)',
    );
    return strings!;
  }

  static AppStrings forLocale(Locale locale) =>
      locale.languageCode == 'en' ? const AppStringsEn() : const AppStringsEs();

  // General
  String get appTitle;

  // Search screen
  String get loginLabel;
  String get searchButton;
  String get loginEmptyError;
  String get loginInvalidError;

  // Request errors
  String get networkError;
  String get timeoutError;
  String get authError;
  String get notFoundError;
  String get rateLimitError;
  String retryAfterHint(int seconds);
  String get serverError;
  String get unexpectedError;

  // Profile screen
  String get emailLabel;
  String get phoneLabel;
  String get locationLabel;
  String get statusLabel;
  String get onlineOn;
  String get onlineOff;
  String get levelLabel;
  String get walletLabel;
  String get correctionPointsLabel;

  // Skills and projects
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

  // Configuration error screen
  String get configErrorTitle;
  String configMissing(List<String> keys);
  String get configUnreadable;
  String get configHint;

  /// Name of a known projects section. The `switch` over the enum is
  /// exhaustive.
  String projectCategoryTitle(ProjectCategory category) => switch (category) {
        ProjectCategory.outerCore => projectsOuterCore,
        ProjectCategory.commonCore => projectsCommonCore,
        ProjectCategory.piscine => projectsPiscine,
        ProjectCategory.piscineReloaded => projectsPiscineReloaded,
      };

  /// Title of any projects section. A known section is translated; the section
  /// of another cursus carries the cursus name from the API as it is (it is
  /// data, not our text, and it cannot be known in advance). The `switch` over
  /// the sealed class is exhaustive.
  String projectSectionTitle(ProjectSection section) => switch (section) {
        KnownSection(:final category) => projectCategoryTitle(category),
        CursusSection(:final name) => name,
      };

  /// Text of a login problem. The `switch` over the enum is exhaustive.
  String loginProblemText(LoginProblem problem) => switch (problem) {
        LoginProblem.empty => loginEmptyError,
        LoginProblem.invalidChars => loginInvalidError,
      };

  /// Text of a request error. The `switch` over the sealed class is exhaustive:
  /// a new kind of error without a translation will not compile.
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

  /// `SynchronousFuture`: our texts are in the code, there is nothing to wait
  /// for, and the first frame is drawn at once, without flicker.
  @override
  Future<AppStrings> load(Locale locale) =>
      SynchronousFuture<AppStrings>(AppStrings.forLocale(locale));

  @override
  bool shouldReload(_AppStringsDelegate old) => false;
}
