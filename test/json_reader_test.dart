import 'package:flutter_test/flutter_test.dart';
import 'package:swifty_companion/core/display.dart';
import 'package:swifty_companion/core/json_reader.dart';

void main() {
  group('readString', () {
    test('обычный текст обрезается по краям', () {
      expect(readString('  abc '), 'abc');
    });

    test('null, пустая строка и пробелы дают null', () {
      expect(readString(null), isNull);
      expect(readString(''), isNull);
      expect(readString('   '), isNull);
    });

    test('«hidden» в любом регистре дает null', () {
      expect(readString('hidden'), isNull);
      expect(readString('HIDDEN'), isNull);
      expect(readString(' Hidden '), isNull);
    });

    test('целое число превращается в строку, остальные типы дают null', () {
      expect(readString(2023), '2023');
      expect(readString(true), isNull);
      expect(readString(['a']), isNull);
    });
  });

  group('числа', () {
    test('readDouble принимает и int, и double', () {
      expect(readDouble(0), 0.0);
      expect(readDouble(7), 7.0);
      expect(readDouble(9.63), 9.63);
    });

    test('readDouble не принимает текст, NaN и бесконечность', () {
      expect(readDouble('9.63'), isNull);
      expect(readDouble(double.nan), isNull);
      expect(readDouble(double.infinity), isNull);
      expect(readDouble(null), isNull);
    });

    test('readInt округляет дробное и отвергает текст', () {
      expect(readInt(5), 5);
      expect(readInt(4.6), 5);
      expect(readInt('5'), isNull);
      expect(readInt(null), isNull);
    });
  });

  group('структуры', () {
    test('readMap и readList не падают на чужих типах', () {
      expect(readMap('x'), isNull);
      expect(readMap(<String, dynamic>{'a': 1}), {'a': 1});
      expect(readList(null), isEmpty);
      expect(readList('x'), isEmpty);
      expect(readList([1, 2]), [1, 2]);
    });

    test('readDate разбирает ISO 8601 и отвергает мусор', () {
      expect(readDate('2024-03-01T10:00:00.000Z'), isNotNull);
      expect(readDate('вчера'), isNull);
      expect(readDate(null), isNull);
    });

    test('readObjects пропускает элементы, которые не объекты', () {
      final names = readObjects<String>(
        [
          {'n': 'a'},
          'мусор',
          null,
          {'n': 'b'},
        ],
        (json) => json['n'] as String,
      );
      expect(names, ['a', 'b']);
    });
  });

  group('display', () {
    test('orNA подставляет N/A только вместо null', () {
      const String? missing = null;
      expect(missing.orNA, 'N/A');
      expect('abc'.orNA, 'abc');
      expect(42.orNA, '42');
    });

    test('formatLevel и formatPercent', () {
      expect(formatLevel(9.63), '9.63');
      expect(formatLevel(3), '3.00');
      expect(formatPercent(48.15), '48 %');
    });
  });
}
