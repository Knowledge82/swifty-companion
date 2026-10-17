/// Что показываем, когда данных нет или они скрыты.
const String notAvailable = 'N/A';

extension NotAvailableX on Object? {
  /// Значение как текст или «N/A», если его нет.
  /// Модели уже превратили `"hidden"` и пустые строки в `null`.
  String get orNA => this?.toString() ?? notAvailable;
}

/// Уровень с двумя знаками: `9.63`, `3.00`.
String formatLevel(double level) => level.toStringAsFixed(2);

/// Процент целым числом: `48 %`.
String formatPercent(double percent) => '${percent.round()} %';
