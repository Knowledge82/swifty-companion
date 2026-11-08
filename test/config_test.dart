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

    test('toString does not reveal secrets', () {
      const config = AppConfig(
        clientId: 'u-secret-1',
        clientSecret: 's-secret-2',
      );
      expect(config.toString(), isNot(contains('secret')));
    });
  });
}
