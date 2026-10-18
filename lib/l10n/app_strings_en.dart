import 'app_strings.dart';

/// Английский. Включается, если язык телефона английский.
class AppStringsEn extends AppStrings {
  const AppStringsEn();

  @override
  String get appTitle => 'Swifty Companion';

  @override
  String get loginLabel => '42 login';
  @override
  String get searchButton => 'Search';
  @override
  String get loginEmptyError => 'Enter a login';
  @override
  String get loginInvalidError => 'Latin letters, digits, "-" and "_" only';

  @override
  String get networkError =>
      'No internet connection. Check your network and try again.';
  @override
  String get timeoutError =>
      'The server did not respond in time. Please try again later.';
  @override
  String get authError =>
      'Could not authenticate with the 42 API. Check the keys in the .env file.';
  @override
  String get notFoundError => 'No user found with that login.';
  @override
  String get rateLimitError => 'Too many requests. Wait a moment and try again.';
  @override
  String retryAfterHint(int seconds) => 'You can retry in $seconds s.';
  @override
  String get serverError =>
      'The 42 API server is unavailable right now. Please try again later.';
  @override
  String get unexpectedError => 'Unexpected response from the server.';

  @override
  String get emailLabel => 'Email';
  @override
  String get phoneLabel => 'Phone';
  @override
  String get locationLabel => 'Location';
  @override
  String get levelLabel => 'Level';
  @override
  String get walletLabel => 'Wallet';
  @override
  String get correctionPointsLabel => 'Evaluation points';

  @override
  String get skillsTitle => 'Skills';
  @override
  String get skillsEmpty => 'No skills yet';
  @override
  String skillsFormulaNote(int maxLevel) =>
      'Calculated percentage: level ÷ $maxLevel (the API does not provide it)';
  @override
  String get projectsTitle => 'Completed projects';
  @override
  String get projectsEmpty => 'No completed projects yet';
  @override
  String get projectPassed => 'Passed';
  @override
  String get projectFailed => 'Failed';
  @override
  String get projectUnknown => 'No result';
  @override
  String get unnamed => 'Unnamed';

  @override
  String get configErrorTitle => 'Configuration error';
  @override
  String configMissing(List<String> keys) =>
      'Missing values in .env: ${keys.join(', ')}';
  @override
  String get configUnreadable => 'Could not read the .env file from the assets';
  @override
  String get configHint =>
      'Copy .env.example to .env, fill in FT_UID and FT_SECRET, and rebuild the app.';
}
