import 'package:flutter_test/flutter_test.dart';
import 'package:swifty_companion/data/user_repository.dart';

import 'fake_api.dart';

void main() {
  test('журнал содержит факты о токене и запросе, но не секреты', () async {
    final fake = FakeApi();

    await UserRepository(fake.api).fetchUser('jdoe');

    expect(fake.logs, contains('Получен токен, срок жизни 7200 с'));
    expect(
      fake.logs.any((l) => l.startsWith('GET /v2/users/jdoe → 200, ')),
      isTrue,
      reason: 'журнал: ${fake.logs}',
    );
    final all = fake.logs.join('\n');
    expect(all, isNot(contains('tok-1')));
    expect(all, isNot(contains('test-secret')));
    expect(all, isNot(contains('test-uid')));
  });

  test('после 401 в журнале есть сброс токена и новый токен', () async {
    final fake = FakeApi(
      onUser: (request, attempt) async =>
          attempt == 1 ? jsonResponse({}, 401) : jsonResponse({'login': 'jdoe'}),
    );

    await UserRepository(fake.api).fetchUser('jdoe');

    expect(fake.logs, contains('Токен отвергнут сервером и сброшен'));
    expect(
      fake.logs.where((l) => l.startsWith('Получен токен')),
      hasLength(2),
    );
    expect(fake.logs.join('\n'), isNot(contains('tok-')));
  });
}
