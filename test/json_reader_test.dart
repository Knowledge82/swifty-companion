import 'package:flutter_test/flutter_test.dart';
import 'package:swifty_companion/core/display.dart';
import 'package:swifty_companion/core/json_reader.dart';

void main() {
  group('readString', () {
    test('plain text is trimmed at the edges', () {
      expect(readString('  abc '), 'abc');
    });

    test('null, an empty string and spaces give null', () {
      expect(readString(null), isNull);
      expect(readString(''), isNull);
      expect(readString('   '), isNull);
    });

    test('"hidden" in any case gives null', () {
      expect(readString('hidden'), isNull);
      expect(readString('HIDDEN'), isNull);
      expect(readString(' Hidden '), isNull);
    });

    test('an integer turns into a string, other types give null', () {
      expect(readString(2023), '2023');
      expect(readString(true), isNull);
      expect(readString(['a']), isNull);
    });
  });

  group('numbers', () {
    test('readDouble accepts both int and double', () {
      expect(readDouble(0), 0.0);
      expect(readDouble(7), 7.0);
      expect(readDouble(9.63), 9.63);
    });

    test('readDouble rejects text, NaN and infinity', () {
      expect(readDouble('9.63'), isNull);
      expect(readDouble(double.nan), isNull);
      expect(readDouble(double.infinity), isNull);
      expect(readDouble(null), isNull);
    });

    test('readInt rounds a fraction and rejects text', () {
      expect(readInt(5), 5);
      expect(readInt(4.6), 5);
      expect(readInt('5'), isNull);
      expect(readInt(null), isNull);
    });
  });

  group('structures', () {
    test('readMap and readList do not crash on foreign types', () {
      expect(readMap('x'), isNull);
      expect(readMap(<String, dynamic>{'a': 1}), {'a': 1});
      expect(readList(null), isEmpty);
      expect(readList('x'), isEmpty);
      expect(readList([1, 2]), [1, 2]);
    });

    test('readDate parses ISO 8601 and rejects junk', () {
      expect(readDate('2024-03-01T10:00:00.000Z'), isNotNull);
      expect(readDate('yesterday'), isNull);
      expect(readDate(null), isNull);
    });

    test('readObjects skips elements that are not objects', () {
      final names = readObjects<String>(
        [
          {'n': 'a'},
          'junk',
          null,
          {'n': 'b'},
        ],
        (json) => json['n'] as String,
      );
      expect(names, ['a', 'b']);
    });
  });

  group('display', () {
    test('orNA substitutes N/A only for null', () {
      const String? missing = null;
      expect(missing.orNA, 'N/A');
      expect('abc'.orNA, 'abc');
      expect(42.orNA, '42');
    });

    test('formatLevel and formatPercent', () {
      expect(formatLevel(9.63), '9.63');
      expect(formatLevel(3), '3.00');
      expect(formatPercent(48.15), '48 %');
    });
  });
}
