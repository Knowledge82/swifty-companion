import 'package:flutter_test/flutter_test.dart';
import 'package:swifty_companion/core/api_exception.dart';

/// If you add a new `ApiException` subclass and do not add it here, this file
/// will stop compiling: a `switch` over a sealed class must be exhaustive.
String kind(ApiException e) => switch (e) {
      NetworkException() => 'network',
      AuthException() => 'auth',
      NotFoundException() => 'notFound',
      RateLimitException() => 'rateLimit',
      ServerException() => 'server',
      UnexpectedResponseException() => 'unexpected',
    };

void main() {
  const all = <ApiException>[
    NetworkException(),
    NetworkException.timeout(),
    AuthException(),
    NotFoundException(),
    RateLimitException(),
    ServerException(),
    UnexpectedResponseException(),
  ];

  test('every error has a non-empty unique message', () {
    final messages = all.map((e) => e.message).toList();
    expect(messages.every((m) => m.isNotEmpty), isTrue);
    expect(messages.toSet().length, messages.length);
  });

  test('switch tells all kinds apart', () {
    expect(all.map(kind).toSet(), {
      'network',
      'auth',
      'notFound',
      'rateLimit',
      'server',
      'unexpected',
    });
  });

  test('isTimeout tells a timeout from a lost network', () {
    expect(const NetworkException().isTimeout, isFalse);
    expect(const NetworkException.timeout().isTimeout, isTrue);
  });

  test('toString contains the type and the message', () {
    expect(const NotFoundException().toString(), contains('NotFoundException'));
    expect(const NotFoundException().toString(), contains('not found'));
  });
}
