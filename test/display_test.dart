import 'package:flutter_test/flutter_test.dart';
import 'package:swifty_companion/core/display.dart';

void main() {
  group('levelFraction', () {
    test('дробная часть уровня', () {
      expect(levelFraction(9.63), closeTo(0.63, 1e-9));
      expect(levelFraction(3), 0);
      expect(levelFraction(0), 0);
    });
  });

  group('formatDate', () {
    test('год-месяц-день с ведущими нулями', () {
      expect(formatDate(DateTime.utc(2024, 3, 1, 10)), '2024-03-01');
      expect(formatDate(DateTime.utc(2024, 12, 25)), '2024-12-25');
    });
  });

  group('initialsOf', () {
    test('первые буквы первых двух слов', () {
      expect(initialsOf('Jane Doe'), 'JD');
      expect(initialsOf('Jean-Luc Picard'), 'JP');
      expect(initialsOf('a b c'), 'AB');
    });

    test('одно слово — одна буква', () {
      expect(initialsOf('madonna'), 'M');
    });

    test('лишние пробелы не мешают', () {
      expect(initialsOf('  jane   doe  '), 'JD');
    });

    test('испанские буквы с диакритикой', () {
      expect(initialsOf('ñandú pérez'), 'ÑP');
    });

    test('пустая строка и пробелы — пустой результат', () {
      expect(initialsOf(''), '');
      expect(initialsOf('   '), '');
    });
  });
}
