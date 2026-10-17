import 'package:flutter_test/flutter_test.dart';
import 'package:swifty_companion/core/login.dart';

void main() {
  group('normalizeLogin', () {
    test('обрезает пробелы и приводит к нижнему регистру', () {
      expect(normalizeLogin('  VDarsuye \n'), 'vdarsuye');
    });
  });

  group('validateLogin', () {
    test('пустой ввод и пробелы — ошибка', () {
      expect(validateLogin(''), isNotNull);
      expect(validateLogin('   '), isNotNull);
    });

    test('обычные логины проходят', () {
      expect(validateLogin('vdarsuye'), isNull);
      expect(validateLogin('  Vdarsuye '), isNull);
      expect(validateLogin('ab-c_1'), isNull);
    });

    test('опасные и лишние символы отклоняются', () {
      expect(validateLogin('a b'), isNotNull);
      expect(validateLogin('../me'), isNotNull);
      expect(validateLogin('a?b=c'), isNotNull);
      expect(validateLogin('логин'), isNotNull);
    });
  });
}
