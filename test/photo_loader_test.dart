import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:swifty_companion/core/api_exception.dart';
import 'package:swifty_companion/data/user_repository.dart';

import 'fake_api.dart';

const _url = 'https://cdn.intra.42.fr/users/abc123/medium_jdoe.png';

void main() {
  test('downloads the photo with a Bearer token and returns the bytes', () async {
    final fake = FakeApi();

    final bytes = await fake.photos.load(_url);

    expect(bytes, tinyPng);
    final request = fake.photoRequests.single;
    expect(request.url.toString(), _url);
    expect(request.headers['Authorization'], 'Bearer tok-1');
  });

  test('the token is shared by profile and photo: requested once', () async {
    final fake = FakeApi();

    await UserRepository(fake.api).fetchUser('jdoe');
    await fake.photos.load(_url);

    expect(fake.tokenCalls, 1);
    expect(fake.photoRequests.single.headers['Authorization'], 'Bearer tok-1');
  });

  test('a repeated load of the same address comes from the cache', () async {
    final fake = FakeApi();

    await fake.photos.load(_url);
    await fake.photos.load(_url);

    expect(fake.photoRequests, hasLength(1));
  });

  group('the token does not go to foreign addresses', () {
    const bad = <String>[
      'https://evil.example.com/a.png',
      'http://cdn.intra.42.fr/users/a/b.png',
      'https://cdn.intra.42.fr@evil.example.com/a.png',
      'https://cdn.intra.42.fr:8443/users/a/b.png',
      'https://cdn.intra.42.fr.evil.example.com/a.png',
      'https://cdn.intra.42.fr',
      'not an address',
      '',
    ];
    for (final url in bad) {
      test('rejected: "$url"', () async {
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

  group('response codes', () {
    Future<void> expectFails<T extends ApiException>(int status) async {
      final fake = FakeApi(
        onPhoto: (request, attempt) async => jsonResponse({}, status),
      );
      await expectLater(fake.photos.load(_url), throwsA(isA<T>()));
      // No extra token requests, no retries.
      expect(fake.tokenCalls, 1);
      expect(fake.photoRequests, hasLength(1));
    }

    test('403 and 401 give AuthException, no retries and no new tokens', () async {
      await expectFails<AuthException>(403);
      await expectFails<AuthException>(401);
    });

    test('404 — NotFoundException', () => expectFails<NotFoundException>(404));
    test('500 — ServerException', () => expectFails<ServerException>(500));

    test('429 passes on Retry-After', () async {
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

    test('a failed response is not cached: a repeat goes to the network', () async {
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

  test('an empty body with 200 gives UnexpectedResponseException', () async {
    final fake = FakeApi(
      onPhoto: (request, attempt) async => http.Response.bytes(const [], 200),
    );
    await expectLater(
      fake.photos.load(_url),
      throwsA(isA<UnexpectedResponseException>()),
    );
  });

  test('a lost network gives NetworkException', () async {
    final fake = FakeApi(
      onPhoto: (request, attempt) async => throw const SocketException('offline'),
    );
    await expectLater(
      fake.photos.load(_url),
      throwsA(isA<NetworkException>()),
    );
  });

  test('the token and an address with a hash do not get into the log in full', () async {
    final fake = FakeApi();

    await fake.photos.load(_url);

    final all = fake.logs.join('\n');
    expect(all, contains('cdn.intra.42.fr'));
    expect(all, isNot(contains('tok-1')));
    expect(all, isNot(contains('abc123')));
  });
}
