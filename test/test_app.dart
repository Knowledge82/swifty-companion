import 'package:material_ui/material_ui.dart';
import 'package:swifty_companion/l10n/app_strings.dart';
import 'package:swifty_companion/ui/steampunk/steampunk_theme.dart';

/// A wrapper for widget tests: the same set of languages and delegates as in
/// the app. The language is set explicitly, otherwise the test environment
/// would pick English and the texts in the checks would depend on the machine's
/// settings.
///
/// [textScale] imitates a large system font.
///
/// [disableAnimations] is `true` by default (like "remove animations" in the
/// system): the rotating gears stand still, and `pumpAndSettle` does not hang
/// on an endless animation. Tests that need motion pass `false`.
Widget testApp(
  Widget home, {
  Locale locale = const Locale('es'),
  double textScale = 1,
  bool disableAnimations = true,
}) {
  return MaterialApp(
    // The real app theme: tests see the same look as the user.
    theme: buildSteampunkTheme(),
    locale: locale,
    localizationsDelegates: AppStrings.localizationsDelegates,
    supportedLocales: AppStrings.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
        disableAnimations: disableAnimations,
      ),
      child: child!,
    ),
    home: home,
  );
}
