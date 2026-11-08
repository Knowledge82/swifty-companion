// Screens should not decide on their own how to print a date or what to write
// in place of a missing email. These are display rules, and they live in one
// place: here.

// 1. What we show when there is no data or it is hidden.
const String notAvailable = 'N/A';

// 2. `extension` lets us "attach" a new method or getter to an existing type
// without touching its code. We cannot edit `int` or `String` from the standard
// library, and an extension gives them a new property. It reads like this:
// "for the type `Object?` a getter `orNA` is added".
extension NotAvailableX on Object? {
  String get orNA => this?.toString() ?? notAvailable;
}

// 3. Initials for the placeholder instead of a photo: the first letters of the
// first two words (`Jane Doe` -> `JD`, `madonna` -> `M`). An empty string if
// there are no words.
String initialsOf(String name) {
  final words = name.split(RegExp(r'\s+'))
		.where((w) => w.isNotEmpty)
		.take(2);
  return words
      .map((w) => String.fromCharCode(w.runes.first).toUpperCase())
      .join();
}

// 4. The fractional part of the level as the share of the way to the next
// level: `9.63` -> `0.63`.
double levelFraction(double level) =>
    (level - level.floorToDouble()).clamp(0.0, 1.0).toDouble();

// 5. The date as `2024-03-01` (the same in any language and any time zone: the
// fields of the value itself are used, with no conversion to local time).
String formatDate(DateTime date) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)}';
}

// 6. The level with two decimals: `9.63`, `3.00`.
String formatLevel(double level) => level.toStringAsFixed(2);

// Percent as a whole number: `48 %`.
String formatPercent(double percent) => '${percent.round()} %';
