/// Безопасное чтение значений из разобранного JSON.
///
/// После `jsonDecode` данные имеют тип `dynamic`: что там на самом деле,
/// известно только во время работы. Эти функции проверяют тип и при
/// несовпадении возвращают `null` (или пустой список), вместо того чтобы
/// падать. Поэтому одно «кривое» поле не роняет весь профиль.

/// Строка, которой интра помечает скрытые данные (например, `phone`).
const String hiddenMarker = 'hidden';

/// Текст или `null`. Для приложения «нет данных» это три разных случая
/// в JSON: `null`, пустая строка и строка `"hidden"`. Все они сводятся к `null`.
String? readString(Object? value) {
  if (value is int) {
    return value.toString();
  }
  if (value is! String) {
    return null;
  }
  final text = value.trim();
  if (text.isEmpty || text.toLowerCase() == hiddenMarker) {
    return null;
  }
  return text;
}

/// Число с плавающей точкой. JSON может отдать и `0`, и `0.0`; оба станут `double`.
double? readDouble(Object? value) {
  if (value is num && value.isFinite) {
    return value.toDouble();
  }
  return null;
}

/// Целое число. Дробное значение округляется.
int? readInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is double && value.isFinite) {
    return value.round();
  }
  return null;
}

bool? readBool(Object? value) => value is bool ? value : null;

/// Объект JSON или `null`.
Map<String, dynamic>? readMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return null;
}

/// Список JSON. Если там не список, возвращается пустой.
List<Object?> readList(Object? value) {
  if (value is List) {
    return value;
  }
  return const <Object?>[];
}

/// Дата в формате ISO 8601 или `null`.
DateTime? readDate(Object? value) {
  final text = readString(value);
  if (text == null) {
    return null;
  }
  return DateTime.tryParse(text);
}

/// Превращает список объектов JSON в список моделей.
/// Элементы, которые не являются объектами, пропускаются.
List<T> readObjects<T>(
  Object? value,
  T Function(Map<String, dynamic> json) parse,
) {
  final result = <T>[];
  for (final item in readList(value)) {
    final map = readMap(item);
    if (map != null) {
      result.add(parse(map));
    }
  }
  return result;
}
