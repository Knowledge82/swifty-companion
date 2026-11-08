import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:swifty_companion/core/api_exception.dart';
import 'package:swifty_companion/core/http_helpers.dart';

void main() {
  group('parseRetryAfter', () {
    test('seconds turn into a Duration', () {
      expect(parseRetryAfter({'retry-after': '30'}), const Duration(seconds: 30));
    });

    test('no header, not a number or negative gives null', () {
      expect(parseRetryAfter({}), isNull);
      expect(parseRetryAfter({'retry-after': 'abc'}), isNull);
      expect(parseRetryAfter({'retry-after': '-5'}), isNull);
    });
  });

  group('decodeJsonObject', () {
    test('reads UTF-8 without charset and even without Content-Type', () {
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

    test('not an object, not JSON and not UTF-8 give UnexpectedResponseException', () {
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
