import 'package:flutter_test/flutter_test.dart';
import 'package:swifty_companion/core/config.dart';

void main() {
  group('AppConfig.fromMap', () {
    test('reads both values and trims spaces', () {
      final config = AppConfig.fromMap({
        'FT_UID': ' u-1 ',
        'FT_SECRET': 's-1',
      });
      expect(config.clientId, 'u-1');
      expect(config.clientSecret, 's-1');
    });

    test('a missing variable gives ConfigException with its name', () {
      expect(
        () => AppConfig.fromMap({'FT_UID': 'u-1'}),
        throwsA(
          isA<ConfigException>().having(
            (e) => e.message,
            'message',
            contains('FT_SECRET'),
          ),
        ),
      );
    });

    test('ConfigException.missing lists all missing names', () {
      expect(
        () => AppConfig.fromMap({}),
        throwsA(
          isA<ConfigException>().having(
            (e) => e.missing,
            'missing',
            ['FT_UID', 'FT_SECRET'],
          ),
        ),
      );
    });

    test('empty values count as missing', () {
      expect(
        () => AppConfig.fromMap({'FT_UID': '', 'FT_SECRET': '  '}),
        throwsA(isA<ConfigException>()),
      );
    });

    // The values are checked, not a word like "secret": the word is part of
    // the field name `clientSecret`, so a check for it would depend on the
    // letter case of the class text and not on whether a value leaks.
    test('toString does not reveal the values', () {
      const config = AppConfig(
        clientId: 'u-secret-1',
        clientSecret: 's-secret-2',
      );
      expect(config.toString(), isNot(contains('u-secret-1')));
      expect(config.toString(), isNot(contains('s-secret-2')));
    });

    test('string interpolation, as in a log message, hides the values too', () {
      const config = AppConfig(
        clientId: 'u-secret-1',
        clientSecret: 's-secret-2',
      );
      final line = 'config is $config';
      expect(line, isNot(contains('u-secret-1')));
      expect(line, isNot(contains('s-secret-2')));
    });

    // The strongest check: if the text does not change when the values
    // change, it cannot contain them. It cannot pass by coincidence.
    test('toString does not depend on the values at all', () {
      const first = AppConfig(clientId: 'aaa', clientSecret: 'bbb');
      const second = AppConfig(clientId: 'xxx', clientSecret: 'yyy');
      expect(first.toString(), second.toString());
    });
  });
}
