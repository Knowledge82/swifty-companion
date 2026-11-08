// Экраны не должны сами решать, как печатать дату или что писать вместо пропавшего email. 
// Это правила показа, и они лежат в одном месте - тут.

// 1. Что показываем, когда данных нет или они скрыты.
const String notAvailable = 'N/A';

// 2. extension позволяет «пришить» новый метод или геттер к уже существующему типу, не трогая его код.
// Мы не можем отредактировать int или String из стандартной библиотеки, а расширение даёт им новое свойство. 
// Читается так: «для типа Object? добавляется геттер orNA».
extension NotAvailableX on Object? {
  String get orNA => this?.toString() ?? notAvailable;
}

// 3. Инициалы для заглушки вместо фото: первые буквы первых двух слов
// (`Jane Doe` → `JD`, `madonna` → `M`). Пустая строка, если слов нет.
String initialsOf(String name) {
  final words = name.split(RegExp(r'\s+'))
		.where((w) => w.isNotEmpty)
		.take(2);
  return words
      .map((w) => String.fromCharCode(w.runes.first).toUpperCase())
      .join();
}

// 4. Дробная часть уровня как доля пути до следующего уровня: `9.63` → `0.63`.
double levelFraction(double level) =>
    (level - level.floorToDouble()).clamp(0.0, 1.0).toDouble();

// 5. Дата как `2024-03-01` (одинаково на любом языке и в любом часовом поясе:
// берутся поля самого значения, без перевода в местное время).
String formatDate(DateTime date) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)}';
}

// 6. Уровень с двумя знаками: `9.63`, `3.00`.
String formatLevel(double level) => level.toStringAsFixed(2);

// Процент целым числом: `48 %`.
String formatPercent(double percent) => '${percent.round()} %';
