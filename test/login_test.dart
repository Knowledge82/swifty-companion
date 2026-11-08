import 'package:flutter_test/flutter_test.dart';
import 'package:swifty_companion/core/login.dart';

void main() {
  group('normalizeLogin', () {
    test('trims spaces and lowercases', () {
      expect(normalizeLogin('  VDarsuye \n'), 'vdarsuye');
    });
  });

  group('validateLogin', () {
    test('empty input and spaces give LoginProblem.empty', () {
      expect(validateLogin(''), LoginProblem.empty);
      expect(validateLogin('   '), LoginProblem.empty);
    });

    test('ordinary logins pass', () {
      expect(validateLogin('vdarsuye'), isNull);
      expect(validateLogin('  Vdarsuye '), isNull);
      expect(validateLogin('ab-c_1'), isNull);
    });

    test('dangerous and extra characters are rejected', () {
      expect(validateLogin('a b'), LoginProblem.invalidChars);
      expect(validateLogin('../me'), LoginProblem.invalidChars);
      expect(validateLogin('a?b=c'), LoginProblem.invalidChars);
      expect(validateLogin('логин'), LoginProblem.invalidChars);
    });
  });
}
