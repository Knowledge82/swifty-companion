import 'package:flutter_test/flutter_test.dart';
import 'package:swifty_companion/core/config.dart';

void main() {
  group('AppConfig.fromMap', () {
    test('читает оба значения и обрезает пробелы', () {
      final config = AppConfig.fromMap({
        'FT_UID': ' u-1 ',
        'FT_SECRET': 's-1',
      });
      expect(config.clientId, 'u-1');
      expect(config.clientSecret, 's-1');
    });

    test('отсутствующая переменная — ConfigException с её именем', () {
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

    test('ConfigException.missing перечисляет все недостающие имена', () {
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

    test('пустые значения считаются отсутствующими', () {
      expect(
        () => AppConfig.fromMap({'FT_UID': '', 'FT_SECRET': '  '}),
        throwsA(isA<ConfigException>()),
      );
    });

    test('toString не раскрывает секреты', () {
      const config = AppConfig(
        clientId: 'u-secret-1',
        clientSecret: 's-secret-2',
      );
      expect(config.toString(), isNot(contains('secret')));
    });
  });
}
