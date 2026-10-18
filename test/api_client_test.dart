import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:swifty_companion/core/api_client.dart';
import 'package:swifty_companion/core/api_exception.dart';

import 'fake_api.dart';
import 'fixtures.dart';

const _path = ['v2', 'users', 'jdoe'];

void main() {
  group('успешный запрос', () {
    test('GET на правильный адрес с Bearer-токеном', () async {
      final fake = FakeApi();

      final json = await fake.api.getJson(_path);

      expect(json['login'], 'jdoe');
      final request = fake.userRequests.single;
      expect(request.method, 'GET');
      expect(request.url.toString(), 'https://api.intra.42.fr/v2/users/jdoe');
      expect(request.headers['Authorization'], 'Bearer tok-1');
      expect(request.headers['Accept'], 'application/json');
    });

    test('токен не запрашивается на каждый запрос', () async {
      final fake = FakeApi();

      await fake.api.getJson(_path);
      await fake.api.getJson(_path);
      await fake.api.getJson(_path);

      expect(fake.userRequests.length, 3);
      expect(fake.tokenCalls, 1);
    });

    test('два параллельных запроса — один запрос токена', () async {
      final fake = FakeApi();

      await Future.wait([fake.api.getJson(_path), fake.api.getJson(_path)]);

      expect(fake.userRequests.length, 2);
      expect(fake.tokenCalls, 1);
    });

    test('части пути кодируются и не меняют структуру адреса', () async {
      final fake = FakeApi();

      await fake.api.getJson(['v2', 'users', 'a b/c?d']);

      final url = fake.userRequests.single.url;
      expect(url.path, '/v2/users/a%20b%2Fc%3Fd');
      expect(url.query, isEmpty);
    });

    test('тело читается как UTF-8 без указания charset', () async {
      final fake = FakeApi(
        onUser: (request, attempt) async => http.Response.bytes(
          utf8.encode(jsonEncode({'login': 'jdoe', 'displayname': 'José Ñandú'})),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );

      final json = await fake.api.getJson(_path);

      expect(json['displayname'], 'José Ñandú');
    });
  });

  group('повтор после 401', () {
    test('401, затем 200: новый токен и ровно один повтор', () async {
      final fake = FakeApi(
        onUser: (request, attempt) async =>
            attempt == 1 ? jsonResponse({}, 401) : jsonResponse(sampleUserJson()),
      );

      final json = await fake.api.getJson(_path);

      expect(json['login'], 'jdoe');
      expect(
        fake.userRequests.map((r) => r.headers['Authorization']),
        ['Bearer tok-1', 'Bearer tok-2'],
      );
      expect(fake.tokenCalls, 2);
    });

    test('два 401 подряд: AuthException, повтор был только один', () async {
      final fake = FakeApi(
        onUser: (request, attempt) async => jsonResponse({}, 401),
      );

      await expectLater(
        fake.api.getJson(_path),
        throwsA(isA<AuthException>()),
      );

      expect(fake.userRequests.length, 2);
      expect(fake.tokenCalls, 2);
    });

    test('ошибка получения токена пробрасывается, запрос профиля не уходит', () async {
      final fake = FakeApi(tokenStatus: 401);

      await expectLater(
        fake.api.getJson(_path),
        throwsA(isA<AuthException>()),
      );

      expect(fake.userRequests, isEmpty);
    });
  });

  group('коды ответа', () {
    final cases = <(int, Matcher)>[
      (404, isA<NotFoundException>()),
      (429, isA<RateLimitException>()),
      (500, isA<ServerException>()),
      (503, isA<ServerException>()),
      (403, isA<UnexpectedResponseException>()),
      (418, isA<UnexpectedResponseException>()),
    ];

    for (final (status, matcher) in cases) {
      test('HTTP $status', () async {
        final fake = FakeApi(
          onUser: (request, attempt) async => jsonResponse({}, status),
        );
        await expectLater(fake.api.getJson(_path), throwsA(matcher));
      });
    }

    test('429 передаёт Retry-After', () async {
      final fake = FakeApi(
        onUser: (request, attempt) async =>
            jsonResponse({}, 429, {'retry-after': '7'}),
      );

      await expectLater(
        fake.api.getJson(_path),
        throwsA(
          isA<RateLimitException>().having(
            (e) => e.retryAfter,
            'retryAfter',
            const Duration(seconds: 7),
          ),
        ),
      );
    });
  });

  group('сеть', () {
    test('SocketException и ClientException — NetworkException', () async {
      for (final error in <Exception>[
        const SocketException('offline'),
        http.ClientException('offline'),
      ]) {
        final fake = FakeApi(onUser: (request, attempt) async => throw error);
        await expectLater(
          fake.api.getJson(_path),
          throwsA(isA<NetworkException>()),
        );
      }
    });

    test('таймаут — NetworkException с текстом про время', () async {
      final fake = FakeApi(
        onUser: (request, attempt) => Completer<http.Response>().future,
      );
      final api = ApiClient(
        tokenService: fake.tokens,
        client: fake.client,
        requestTimeout: const Duration(milliseconds: 50),
      );

      await expectLater(
        api.getJson(_path),
        throwsA(
          isA<NetworkException>().having(
            (e) => e.message,
            'message',
            contains('вовремя'),
          ),
        ),
      );
    });
  });

  test('200, но тело не годится: UnexpectedResponseException', () async {
    final bodies = <List<int>>[
      utf8.encode('not json'),
      utf8.encode('[]'),
      utf8.encode(''),
      [0xff, 0xfe, 0xfd],
    ];
    for (final body in bodies) {
      final fake = FakeApi(
        onUser: (request, attempt) async => http.Response.bytes(body, 200),
      );
      await expectLater(
        fake.api.getJson(_path),
        throwsA(isA<UnexpectedResponseException>()),
      );
    }
  });
}
