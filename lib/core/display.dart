/// Что показываем, когда данных нет или они скрыты.
const String notAvailable = 'N/A';

extension NotAvailableX on Object? {
  /// Значение как текст или «N/A», если его нет.
  /// Модели уже превратили `"hidden"` и пустые строки в `null`.
  String get orNA => this?.toString() ?? notAvailable;
}

/// Инициалы для заглушки вместо фото: первые буквы первых двух слов
/// (`Jane Doe` → `JD`, `madonna` → `M`). Пустая строка, если слов нет.
String initialsOf(String name) {
  final words = name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2);
  return words
      .map((w) => String.fromCharCode(w.runes.first).toUpperCase())
      .join();
}

/// Уровень с двумя знаками: `9.63`, `3.00`.
String formatLevel(double level) => level.toStringAsFixed(2);

/// Процент целым числом: `48 %`.
String formatPercent(double percent) => '${percent.round()} %';
