import 'package:flutter_test/flutter_test.dart';
import 'package:swifty_companion/core/display.dart';

void main() {
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
