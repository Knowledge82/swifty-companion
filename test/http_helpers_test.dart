import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:swifty_companion/core/api_exception.dart';
import 'package:swifty_companion/core/http_helpers.dart';

void main() {
  group('parseRetryAfter', () {
    test('секунды превращаются в Duration', () {
      expect(parseRetryAfter({'retry-after': '30'}), const Duration(seconds: 30));
    });

    test('нет заголовка, не число или отрицательное — null', () {
      expect(parseRetryAfter({}), isNull);
      expect(parseRetryAfter({'retry-after': 'abc'}), isNull);
      expect(parseRetryAfter({'retry-after': '-5'}), isNull);
    });
  });

  group('decodeJsonObject', () {
    test('читает UTF-8 без charset и вообще без Content-Type', () {
      final bytes = utf8.encode('{"name":"José Ñandú"}');
      final withoutCharset = http.Response.bytes(
        bytes,
        200,
        headers: {'content-type': 'application/json'},
      );
      final withoutHeader = http.Response.bytes(bytes, 200);

      expect(decodeJsonObject(withoutCharset)['name'], 'José Ñandú');
      expect(decodeJsonObject(withoutHeader)['name'], 'José Ñandú');
    });

    test('не объект, не JSON и не UTF-8 — UnexpectedResponseException', () {
      final bad = <http.Response>[
        http.Response('[]', 200),
        http.Response('not json', 200),
        http.Response('', 200),
        http.Response.bytes([0xff, 0xfe, 0xfd], 200),
      ];
      for (final response in bad) {
        expect(
          () => decodeJsonObject(response),
          throwsA(isA<UnexpectedResponseException>()),
        );
      }
    });
  });
}
