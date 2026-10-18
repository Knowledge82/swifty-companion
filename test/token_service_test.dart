import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:swifty_companion/core/api_exception.dart';
import 'package:swifty_companion/core/config.dart';
import 'package:swifty_companion/core/token_service.dart';

const _config = AppConfig(clientId: 'test-uid', clientSecret: 'test-secret');

http.Response _json(Object body, [int status = 200, Map<String, String>? headers]) {
  return http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json', ...?headers},
  );
}

http.Response _token(String value, {int? expiresIn = 7200}) {
  return _json({
    'access_token': value,
    'token_type': 'bearer',
    if (expiresIn != null) 'expires_in': expiresIn,
  });
}

void main() {
  final start = DateTime.utc(2026, 10, 18, 12);
  late DateTime clock;

  setUp(() => clock = start);

  TokenService make(
    http.Client client, {
    Duration requestTimeout = const Duration(seconds: 15),
  }) {
    return TokenService(
      config: _config,
      client: client,
      now: () => clock,
      requestTimeout: requestTimeout,
    );
  }

  group('запрос токена', () {
    test('один POST на правильный адрес, секрет в теле, а не в адресе', () async {
      late http.Request seen;
      var calls = 0;
      final service = make(MockClient((request) async {
        calls++;
        seen = request;
        return _token('tok-1');
      }));

      expect(await service.getToken(), 'tok-1');

      expect(calls, 1);
      expect(seen.method, 'POST');
      expect(seen.url.toString(), 'https://api.intra.42.fr/oauth/token');
      expect(seen.url.query, isEmpty);
      expect(seen.bodyFields, {
        'grant_type': 'client_credentials',
        'client_id': 'test-uid',
        'client_secret': 'test-secret',
      });
    });
  });

  group('кэш и срок жизни', () {
    test('повторные вызовы берут токен из памяти', () async {
      var calls = 0;
      final service = make(MockClient((_) async => _token('tok-${++calls}')));

      expect(await service.getToken(), 'tok-1');
      expect(await service.getToken(), 'tok-1');
      expect(await service.getToken(), 'tok-1');
      expect(calls, 1);
    });

    test('после истечения (с запасом 60 с) берётся новый токен', () async {
      var calls = 0;
      final service = make(MockClient((_) async => _token('tok-${++calls}')));

      expect(await service.getToken(), 'tok-1');

      clock = start.add(const Duration(seconds: 7139)); // до границы 7200 - 60
      expect(await service.getToken(), 'tok-1');
      expect(calls, 1);

      clock = start.add(const Duration(seconds: 7140)); // ровно граница
      expect(await service.getToken(), 'tok-2');
      expect(calls, 2);
    });

    test('без expires_in действует срок по умолчанию (1 час)', () async {
      var calls = 0;
      final service = make(
        MockClient((_) async => _token('tok-${++calls}', expiresIn: null)),
      );

      await service.getToken();
      clock = start.add(const Duration(seconds: 3539));
      await service.getToken();
      expect(calls, 1);

      clock = start.add(const Duration(seconds: 3540));
      await service.getToken();
      expect(calls, 2);
    });

    test('expires_in = 0 тоже заменяется сроком по умолчанию', () async {
      var calls = 0;
      final service = make(
        MockClient((_) async => _token('tok-${++calls}', expiresIn: 0)),
      );

      await service.getToken();
      await service.getToken();
      expect(calls, 1);
    });
  });

  group('параллельные вызовы', () {
    test('пять одновременных getToken дают один запрос', () async {
      final gate = Completer<void>();
      var calls = 0;
      final service = make(MockClient((_) async {
        calls++;
        await gate.future;
        return _token('tok-1');
      }));

      final futures = List.generate(5, (_) => service.getToken());
      await Future<void>.delayed(Duration.zero); // запрос ещё «в пути»
      expect(calls, 1);

      gate.complete();
      final tokens = await Future.wait(futures);

      expect(tokens, everyElement('tok-1'));
      expect(calls, 1);
    });

    test('ошибка не кэшируется: следующий вызов пробует снова', () async {
      var calls = 0;
      final service = make(MockClient((_) async {
        calls++;
        return calls == 1 ? _json({'error': 'down'}, 503) : _token('tok-2');
      }));

      await expectLater(service.getToken(), throwsA(isA<ServerException>()));
      expect(await service.getToken(), 'tok-2');
      expect(calls, 2);
    });

    test('все ожидающие получают одну и ту же ошибку', () async {
      final gate = Completer<void>();
      var calls = 0;
      final service = make(MockClient((_) async {
        calls++;
        await gate.future;
        return _json({'error': 'down'}, 503);
      }));

      final results = List.generate(3, (_) => service.getToken());
      final checks = results
          .map((f) => expectLater(f, throwsA(isA<ServerException>())))
          .toList();
      await Future<void>.delayed(Duration.zero);
      gate.complete();
      await Future.wait(checks);

      expect(calls, 1);
    });
  });

  group('invalidate', () {
    test('после invalidate берётся новый токен', () async {
      var calls = 0;
      final service = make(MockClient((_) async => _token('tok-${++calls}')));

      final first = await service.getToken();
      service.invalidate(first);

      expect(await service.getToken(), 'tok-2');
      expect(calls, 2);
    });

    test('запоздалый invalidate старого токена не стирает новый', () async {
      var calls = 0;
      final service = make(MockClient((_) async => _token('tok-${++calls}')));

      final old = await service.getToken(); // tok-1
      service.invalidate(old); // первый запрос получил 401
      expect(await service.getToken(), 'tok-2');

      service.invalidate(old); // второй запрос с тем же tok-1 получил 401 позже
      expect(await service.getToken(), 'tok-2');
      expect(calls, 2); // третьего токена не потребовалось
    });
  });

  group('ошибки токена', () {
    final cases = <(int, Matcher)>[
      (400, isA<AuthException>()),
      (401, isA<AuthException>()),
      (403, isA<AuthException>()),
      (429, isA<RateLimitException>()),
      (500, isA<ServerException>()),
      (503, isA<ServerException>()),
      (404, isA<UnexpectedResponseException>()),
      (418, isA<UnexpectedResponseException>()),
    ];

    for (final (status, matcher) in cases) {
      test('HTTP $status', () async {
        final service = make(
          MockClient((_) async => _json({'error': 'invalid_client'}, status)),
        );
        await expectLater(service.getToken(), throwsA(matcher));
      });
    }

    test('429 передаёт Retry-After', () async {
      final service = make(
        MockClient((_) async => _json({}, 429, {'retry-after': '30'})),
      );
      await expectLater(
        service.getToken(),
        throwsA(
          isA<RateLimitException>().having(
            (e) => e.retryAfter,
            'retryAfter',
            const Duration(seconds: 30),
          ),
        ),
      );
    });

    test('в тексте ошибки нет ни секрета, ни идентификатора', () async {
      final service = make(MockClient((_) async => _json({}, 401)));
      try {
        await service.getToken();
        fail('ожидалась AuthException');
      } on AuthException catch (e) {
        expect(e.toString(), isNot(contains('test-secret')));
        expect(e.toString(), isNot(contains('test-uid')));
      }
    });

    test('нет сети: SocketException и ClientException', () async {
      for (final error in <Exception>[
        const SocketException('offline'),
        http.ClientException('offline'),
      ]) {
        final service = make(MockClient((_) async => throw error));
        await expectLater(service.getToken(), throwsA(isA<NetworkException>()));
      }
    });

    test('таймаут даёт NetworkException с текстом про время', () async {
      final service = make(
        MockClient((_) => Completer<http.Response>().future),
        requestTimeout: const Duration(milliseconds: 50),
      );
      await expectLater(
        service.getToken(),
        throwsA(
          isA<NetworkException>().having(
            (e) => e.message,
            'message',
            contains('вовремя'),
          ),
        ),
      );
    });

    test('200, но тело не годится: UnexpectedResponseException', () async {
      final bodies = <String>[
        'not json at all', // только ASCII: http.Response кодирует тело в latin1
        '[]',
        '{}',
        '{"access_token": ""}',
        '{"access_token": 123}',
      ];
      for (final body in bodies) {
        final service = make(MockClient((_) async => http.Response(body, 200)));
        await expectLater(
          service.getToken(),
          throwsA(isA<UnexpectedResponseException>()),
          reason: 'тело: $body',
        );
      }
    });
  });
}
