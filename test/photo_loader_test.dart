import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:swifty_companion/core/api_exception.dart';
import 'package:swifty_companion/data/user_repository.dart';

import 'fake_api.dart';

const _url = 'https://cdn.intra.42.fr/users/abc123/medium_jdoe.png';

void main() {
  test('скачивает фото с Bearer-токеном и возвращает байты', () async {
    final fake = FakeApi();

    final bytes = await fake.photos.load(_url);

    expect(bytes, tinyPng);
    final request = fake.photoRequests.single;
    expect(request.url.toString(), _url);
    expect(request.headers['Authorization'], 'Bearer tok-1');
  });

  test('токен общий для профиля и фото: запрошен один раз', () async {
    final fake = FakeApi();

    await UserRepository(fake.api).fetchUser('jdoe');
    await fake.photos.load(_url);

    expect(fake.tokenCalls, 1);
    expect(fake.photoRequests.single.headers['Authorization'], 'Bearer tok-1');
  });

  test('повторная загрузка того же адреса берётся из кэша', () async {
    final fake = FakeApi();

    await fake.photos.load(_url);
    await fake.photos.load(_url);

    expect(fake.photoRequests, hasLength(1));
  });

  group('токен не уходит на чужие адреса', () {
    const bad = <String>[
      'https://evil.example.com/a.png',
      'http://cdn.intra.42.fr/users/a/b.png',
      'https://cdn.intra.42.fr@evil.example.com/a.png',
      'https://cdn.intra.42.fr:8443/users/a/b.png',
      'https://cdn.intra.42.fr.evil.example.com/a.png',
      'https://cdn.intra.42.fr',
      'не адрес',
      '',
    ];
    for (final url in bad) {
      test('отклонён: "$url"', () async {
        final fake = FakeApi();

        await expectLater(
          fake.photos.load(url),
          throwsA(isA<UnexpectedResponseException>()),
        );

        expect(fake.tokenCalls, 0);
        expect(fake.photoRequests, isEmpty);
      });
    }
  });

  group('коды ответа', () {
    Future<void> expectFails<T extends ApiException>(int status) async {
      final fake = FakeApi(
        onPhoto: (request, attempt) async => jsonResponse({}, status),
      );
      await expectLater(fake.photos.load(_url), throwsA(isA<T>()));
      // Лишних запросов токена нет, повторов нет.
      expect(fake.tokenCalls, 1);
      expect(fake.photoRequests, hasLength(1));
    }

    test('403 и 401 — AuthException, без повторов и новых токенов', () async {
      await expectFails<AuthException>(403);
      await expectFails<AuthException>(401);
    });

    test('404 — NotFoundException', () => expectFails<NotFoundException>(404));
    test('500 — ServerException', () => expectFails<ServerException>(500));

    test('429 передаёт Retry-After', () async {
      final fake = FakeApi(
        onPhoto: (request, attempt) async =>
            jsonResponse({}, 429, {'retry-after': '12'}),
      );
      await expectLater(
        fake.photos.load(_url),
        throwsA(
          isA<RateLimitException>().having(
            (e) => e.retryAfter,
            'retryAfter',
            const Duration(seconds: 12),
          ),
        ),
      );
    });

    test('неудачный ответ в кэш не попадает: повтор уходит в сеть', () async {
      final fake = FakeApi(
        onPhoto: (request, attempt) async => attempt == 1
            ? jsonResponse({}, 500)
            : http.Response.bytes(tinyPng, 200),
      );

      await expectLater(fake.photos.load(_url), throwsA(isA<ServerException>()));
      final bytes = await fake.photos.load(_url);

      expect(bytes, tinyPng);
      expect(fake.photoRequests, hasLength(2));
    });
  });

  test('пустое тело при 200 — UnexpectedResponseException', () async {
    final fake = FakeApi(
      onPhoto: (request, attempt) async => http.Response.bytes(const [], 200),
    );
    await expectLater(
      fake.photos.load(_url),
      throwsA(isA<UnexpectedResponseException>()),
    );
  });

  test('сеть пропала — NetworkException', () async {
    final fake = FakeApi(
      onPhoto: (request, attempt) async => throw const SocketException('offline'),
    );
    await expectLater(
      fake.photos.load(_url),
      throwsA(isA<NetworkException>()),
    );
  });

  test('токен и адрес с хешем не попадают в журнал целиком', () async {
    final fake = FakeApi();

    await fake.photos.load(_url);

    final all = fake.logs.join('\n');
    expect(all, contains('cdn.intra.42.fr'));
    expect(all, isNot(contains('tok-1')));
    expect(all, isNot(contains('abc123')));
  });
}
