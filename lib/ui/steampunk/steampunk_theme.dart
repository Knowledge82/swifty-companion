import 'package:flutter/material.dart';

// The "steampunk" palette: brass, copper, dark leather, dark walnut,
// parchment, patina.
// Iteration 5: the tones were brought closer to the splash image (warm browns,
// copper, amber): the green panels became walnut, and green stayed only in
// small accents (oxide on metal, the "passed" icon).
// All colors are collected here so that the whole look of the app changes in
// one place.

const Color brass = Color(0xFFC8A04A);
const Color copper = Color(0xFFB87333);
// Iteration 9: the panels were DARKER than the center of the background
// (#3A2316) and lighter than its edges, so they merged with it (contrast
// 1.13:1). Now the background is darker than the panels everywhere: #24160E in
// the center, `leatherDeep` at the edges.
const Color leather = Color(0xFF24160E); // light in the center of the background
const Color leatherDeep = Color(0xFF170E09); // background edges, AppBar and the splash background
const Color parchment = Color(0xFFEADFC4);
const Color verdigris = Color(0xFF6FB39C);
const Color rust = Color(0xFFE67B61); // was #E0745A: on a light panel it fell short of 4.5:1
const Color mutedBrass = Color(0xFFA8946F);

// Walnut: the panels. Here used to be emerald (emerald `#0F2B21`, emeraldDeep
// `#0A1F17`, emeraldLight `#17402F`): if you want green panels back, put these
// values back, nothing else needs to change.
// The oxide (patina) on brass and copper stays green.
const Color walnutDeep = Color(0xFF1B110B); // input field, the darkest places
const Color walnut = Color(0xFF3B291C); // panel background (was #2A1B12); lighter than the background everywhere
const Color walnutLight = Color(0xFF4E3724); // photo placeholder: differs from the panel
const Color oxide = Color(0xFF3F9E80); // oxide stains on metal

/// The "on campus" lamp: green glows, grey is extinguished. The color is not
/// the only sign: a word is always written next to it ("En el campus" / "Fuera
/// del campus").
const Color onlineGreen = Color(0xFF55D17A);
const Color offlineGray = Color(0xFF868075);

/// The color of the profile section titles ("Habilidades", "Proyectos
/// completados"). It is a lightened oxide: the plain `oxide` (`#3F9E80`) on the
/// new, lighter panel gives only 4.22:1 and fails the 4.5:1 threshold. This one
/// is 5.1:1; if you want it even lighter, use `verdigris` (`#6FB39C`, 5.7:1).
const Color sectionTitleColor = Color(0xFF4DAE8D);

/// The dark color scheme. The text contrast against the background is checked
/// by a test (`steampunk_test.dart`): the main text is at least 7:1, the rest
/// at least 4.5:1.
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
  surface: walnut,
  onSurface: parchment,
  onSurfaceVariant: mutedBrass,
  outline: mutedBrass,
  outlineVariant: Color(0xFF6B5240),
  surfaceContainerHighest: walnutLight,
);

/// A serif font that exists in the Android system (`serif`), so as not to add
/// font files and network loading to the project.
const String _serif = 'serif';

/// The app theme. It is built by a single call of the `ThemeData` constructor
/// (not `copyWith`): this way there is less chance of tripping over changes of
/// the component theme types between Flutter versions.
///
/// The input field styling is intentionally not included here: it is set right
/// at the field through [steampunkInputDecoration].
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

/// Input field styling: a brass border on dark leather.
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
    fillColor: walnutDeep,
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
