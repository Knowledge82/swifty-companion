import 'package:flutter_test/flutter_test.dart';
import 'package:swifty_companion/core/api_exception.dart';
import 'package:swifty_companion/data/user_repository.dart';

import 'fake_api.dart';

void main() {
  test('нормализует логин и собирает профиль из ответа', () async {
    final fake = FakeApi();
    final repository = UserRepository(fake.api);

    final profile = await repository.fetchUser('  JDoe ');

    expect(fake.userRequests.single.url.path, '/v2/users/jdoe');
    expect(profile.login, 'jdoe');
    expect(profile.phone, isNull); // "hidden" уже превращён в null
    expect(profile.mainCursus?.slug, '42cursus');
    expect(
      profile.finishedProjects().map((p) => p.name),
      ['push_swap', 'ft_printf', 'c-piscine-shell-00', 'libft'],
    );
  });

  test('недопустимый логин: NotFoundException и ни одного запроса', () async {
    for (final login in ['', '   ', '../me', 'a b', 'a?b']) {
      final fake = FakeApi();
      final repository = UserRepository(fake.api);

      await expectLater(
        repository.fetchUser(login),
        throwsA(isA<NotFoundException>()),
        reason: 'логин: "$login"',
      );

      expect(fake.tokenCalls, 0, reason: 'логин: "$login"');
      expect(fake.userRequests, isEmpty, reason: 'логин: "$login"');
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

  test('ошибки клиента проходят без изменений', () async {
    final fake = FakeApi(
      onUser: (request, attempt) async => jsonResponse({}, 503),
    );
    await expectLater(
      UserRepository(fake.api).fetchUser('jdoe'),
      throwsA(isA<ServerException>()),
    );
  });

  test('ответ без login — UnexpectedResponseException, не FormatException', () async {
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
        reason: 'тело: $body',
      );
    }
  });

  test('минимальный ответ (только login) даёт пустой, но рабочий профиль', () async {
    final fake = FakeApi(
      onUser: (request, attempt) async => jsonResponse({'login': 'jdoe'}),
    );

    final profile = await UserRepository(fake.api).fetchUser('jdoe');

    expect(profile.login, 'jdoe');
    expect(profile.cursuses, isEmpty);
    expect(profile.finishedProjects(), isEmpty);
  });
}
