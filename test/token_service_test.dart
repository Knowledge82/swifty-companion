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
    'expires_in': ?expiresIn, // "?" means add the pair only if the value is not null
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

  group('token request', () {
    test('one POST to the right address, the secret in the body, not in the address', () async {
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

  group('cache and lifetime', () {
    test('repeated calls take the token from memory', () async {
      var calls = 0;
      final service = make(MockClient((_) async => _token('tok-${++calls}')));

      expect(await service.getToken(), 'tok-1');
      expect(await service.getToken(), 'tok-1');
      expect(await service.getToken(), 'tok-1');
      expect(calls, 1);
    });

    test('after expiry (with a 60 s margin) a new token is taken', () async {
      var calls = 0;
      final service = make(MockClient((_) async => _token('tok-${++calls}')));

      expect(await service.getToken(), 'tok-1');

      clock = start.add(const Duration(seconds: 7139)); // up to the boundary 7200 - 60
      expect(await service.getToken(), 'tok-1');
      expect(calls, 1);

      clock = start.add(const Duration(seconds: 7140)); // exactly the boundary
      expect(await service.getToken(), 'tok-2');
      expect(calls, 2);
    });

    test('without expires_in the default lifetime applies (1 hour)', () async {
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

    test('expires_in = 0 is also replaced by the default lifetime', () async {
      var calls = 0;
      final service = make(
        MockClient((_) async => _token('tok-${++calls}', expiresIn: 0)),
      );

      await service.getToken();
      await service.getToken();
      expect(calls, 1);
    });
  });

  group('parallel calls', () {
    test('five simultaneous getToken calls give one request', () async {
      final gate = Completer<void>();
      var calls = 0;
      final service = make(MockClient((_) async {
        calls++;
        await gate.future;
        return _token('tok-1');
      }));

      final futures = List.generate(5, (_) => service.getToken());
      await Future<void>.delayed(Duration.zero); // the request is still "on the way"
      expect(calls, 1);

      gate.complete();
      final tokens = await Future.wait(futures);

      expect(tokens, everyElement('tok-1'));
      expect(calls, 1);
    });

    test('an error is not cached: the next call tries again', () async {
      var calls = 0;
      final service = make(MockClient((_) async {
        calls++;
        return calls == 1 ? _json({'error': 'down'}, 503) : _token('tok-2');
      }));

      await expectLater(service.getToken(), throwsA(isA<ServerException>()));
      expect(await service.getToken(), 'tok-2');
      expect(calls, 2);
    });

    test('all waiters get the same error', () async {
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
    test('after invalidate a new token is taken', () async {
      var calls = 0;
      final service = make(MockClient((_) async => _token('tok-${++calls}')));

      final first = await service.getToken();
      service.invalidate(first);

      expect(await service.getToken(), 'tok-2');
      expect(calls, 2);
    });

    test('a late invalidate of the old token does not erase the new one', () async {
      var calls = 0;
      final service = make(MockClient((_) async => _token('tok-${++calls}')));

      final old = await service.getToken(); // tok-1
      service.invalidate(old); // the first request got 401
      expect(await service.getToken(), 'tok-2');

      service.invalidate(old); // the second request with the same tok-1 got 401 later
      expect(await service.getToken(), 'tok-2');
      expect(calls, 2); // a third token was not needed
    });
  });

  group('token errors', () {
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

    test('429 passes on Retry-After', () async {
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

    test('the error text contains neither the secret nor the identifier', () async {
      final service = make(MockClient((_) async => _json({}, 401)));
      try {
        await service.getToken();
        fail('AuthException was expected');
      } on AuthException catch (e) {
        expect(e.toString(), isNot(contains('test-secret')));
        expect(e.toString(), isNot(contains('test-uid')));
      }
    });

    test('no network: SocketException and ClientException', () async {
      for (final error in <Exception>[
        const SocketException('offline'),
        http.ClientException('offline'),
      ]) {
        final service = make(MockClient((_) async => throw error));
        await expectLater(service.getToken(), throwsA(isA<NetworkException>()));
      }
    });

    test('a timeout gives NetworkException with text about time', () async {
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
            contains('in time'),
          ),
        ),
      );
    });

    test('200, but the body is unusable: UnexpectedResponseException', () async {
      final bodies = <String>[
        'not json at all', // ASCII only: http.Response encodes the body as latin1
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
          reason: 'body: $body',
        );
      }
    });
  });
}
