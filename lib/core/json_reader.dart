// Safe reading of values from parsed JSON.
//
// After `jsonDecode` the data has type `dynamic`: what is really inside is
// known only at run time. These functions check the type and, on a mismatch,
// return `null` (or an empty list) instead of crashing. So one "broken" field
// does not bring down the whole profile.

/// The string the intra uses to mark hidden data (for example, `phone`).
/// A top-level constant.
const String hiddenMarker = 'hidden';

/// Text or `null`. For the app "no data" is three different cases in JSON:
/// `null`, an empty string and the string `"hidden"`. All of them become
/// `null`.
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

// JSON may give both `0` and `0.0`; both become `double`.
double? readDouble(Object? value) {
  if (value is num && value.isFinite) {
    return value.toDouble();
  }
  return null;
}

// A fractional value is rounded.
int? readInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is double && value.isFinite) {
    return value.round();
  }
  return null;
}

// Bool
bool? readBool(Object? value) => value is bool ? value : null;

// A JSON object or `null`.
Map<String, dynamic>? readMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return null;
}

// A JSON list. If the value is not a list, an empty one is returned.
List<Object?> readList(Object? value) {
  if (value is List) {
    return value;
  }
  return const <Object?>[];
}

// A date in ISO 8601 format or `null`.
DateTime? readDate(Object? value) {
  final text = readString(value);
  if (text == null) {
    return null;
  }
  return DateTime.tryParse(text);
}

// Turns a list of JSON objects into a list of models.
// Elements that are not objects are skipped.
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
