import 'package:flutter_test/flutter_test.dart';
import 'package:swifty_companion/core/display.dart';

void main() {
  group('levelFraction', () {
    test('fractional part of the level', () {
      expect(levelFraction(9.63), closeTo(0.63, 1e-9));
      expect(levelFraction(3), 0);
      expect(levelFraction(0), 0);
    });
  });

  group('formatDate', () {
    test('year-month-day with leading zeros', () {
      expect(formatDate(DateTime.utc(2024, 3, 1, 10)), '2024-03-01');
      expect(formatDate(DateTime.utc(2024, 12, 25)), '2024-12-25');
    });
  });

  group('initialsOf', () {
    test('first letters of the first two words', () {
      expect(initialsOf('Jane Doe'), 'JD');
      expect(initialsOf('Jean-Luc Picard'), 'JP');
      expect(initialsOf('a b c'), 'AB');
    });

    test('one word gives one letter', () {
      expect(initialsOf('madonna'), 'M');
    });

    test('extra spaces do not matter', () {
      expect(initialsOf('  jane   doe  '), 'JD');
    });

    test('Spanish letters with diacritics', () {
      expect(initialsOf('ñandú pérez'), 'ÑP');
    });

    test('an empty string and spaces give an empty result', () {
      expect(initialsOf(''), '');
      expect(initialsOf('   '), '');
    });
  });
}
