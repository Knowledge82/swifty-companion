import 'package:flutter_test/flutter_test.dart';
import 'package:swifty_companion/core/api_exception.dart';
import 'package:swifty_companion/data/user_repository.dart';

import 'fake_api.dart';

void main() {
  test('normalizes the login and builds a profile from the response', () async {
    final fake = FakeApi();
    final repository = UserRepository(fake.api);

    final profile = await repository.fetchUser('  JDoe ');

    expect(fake.userRequests.single.url.path, '/v2/users/jdoe');
    expect(profile.login, 'jdoe');
    expect(profile.phone, isNull); // "hidden" has already been turned into null
    expect(profile.mainCursus?.slug, '42cursus');
    expect(
      profile.finishedProjects().map((p) => p.name),
      ['push_swap', 'ft_printf', 'c-piscine-shell-00', 'libft'],
    );
  });

  test('an invalid login: NotFoundException and no requests', () async {
    for (final login in ['', '   ', '../me', 'a b', 'a?b']) {
      final fake = FakeApi();
      final repository = UserRepository(fake.api);

      await expectLater(
        repository.fetchUser(login),
        throwsA(isA<NotFoundException>()),
        reason: 'login: "$login"',
      );

      expect(fake.tokenCalls, 0, reason: 'login: "$login"');
      expect(fake.userRequests, isEmpty, reason: 'login: "$login"');
    }
  });

  test('404 — NotFoundException', () async {
    final fake = FakeApi(
      onUser: (request, attempt) async => jsonResponse({}, 404),
    );
    await expectLater(
      UserRepository(fake.api).fetchUser('nobody'),
      throwsA(isA<NotFoundException>()),
    );
  });

  test('client errors pass through unchanged', () async {
    final fake = FakeApi(
      onUser: (request, attempt) async => jsonResponse({}, 503),
    );
    await expectLater(
      UserRepository(fake.api).fetchUser('jdoe'),
      throwsA(isA<ServerException>()),
    );
  });

  test('a response without login gives UnexpectedResponseException, not FormatException', () async {
    for (final body in <Map<String, dynamic>>[
      {},
      {'id': 1, 'email': 'x@example.com'},
      {'login': 'hidden'},
    ]) {
      final fake = FakeApi(
        onUser: (request, attempt) async => jsonResponse(body),
      );
      await expectLater(
        UserRepository(fake.api).fetchUser('jdoe'),
        throwsA(isA<UnexpectedResponseException>()),
        reason: 'body: $body',
      );
    }
  });

  test('a minimal response (login only) gives an empty but working profile', () async {
    final fake = FakeApi(
      onUser: (request, attempt) async => jsonResponse({'login': 'jdoe'}),
    );

    final profile = await UserRepository(fake.api).fetchUser('jdoe');

    expect(profile.login, 'jdoe');
    expect(profile.cursuses, isEmpty);
    expect(profile.finishedProjects(), isEmpty);
  });
}
