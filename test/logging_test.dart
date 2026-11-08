import 'package:flutter_test/flutter_test.dart';
import 'package:swifty_companion/data/user_repository.dart';

import 'fake_api.dart';

void main() {
  test('the log contains facts about the token and the request, but no secrets', () async {
    final fake = FakeApi();

    await UserRepository(fake.api).fetchUser('jdoe');

    expect(fake.logs, contains('Token received, lifetime 7200 s'));
    expect(
      fake.logs.any((l) => l.startsWith('GET /v2/users/jdoe → 200, ')),
      isTrue,
      reason: 'log: ${fake.logs}',
    );
    final all = fake.logs.join('\n');
    expect(all, isNot(contains('tok-1')));
    expect(all, isNot(contains('test-secret')));
    expect(all, isNot(contains('test-uid')));
  });

  test('after a 401 the log has a token reset and a new token', () async {
    final fake = FakeApi(
      onUser: (request, attempt) async =>
          attempt == 1 ? jsonResponse({}, 401) : jsonResponse({'login': 'jdoe'}),
    );

    await UserRepository(fake.api).fetchUser('jdoe');

    expect(fake.logs, contains('Token rejected by the server and discarded'));
    expect(
      fake.logs.where((l) => l.startsWith('Token received')),
      hasLength(2),
    );
    expect(fake.logs.join('\n'), isNot(contains('tok-')));
  });
}
