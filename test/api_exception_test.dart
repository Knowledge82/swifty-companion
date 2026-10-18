import 'package:flutter_test/flutter_test.dart';
import 'package:swifty_companion/core/api_exception.dart';

/// Если добавить новый подкласс `ApiException` и не добавить его сюда,
/// этот файл перестанет компилироваться: `switch` по sealed-классу
/// обязан быть исчерпывающим.
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

  test('у каждой ошибки есть непустой уникальный текст для пользователя', () {
    final messages = all.map((e) => e.message).toList();
    expect(messages.every((m) => m.isNotEmpty), isTrue);
    expect(messages.toSet().length, messages.length);
  });

  test('switch различает все виды', () {
    expect(all.map(kind).toSet(), {
      'network',
      'auth',
      'notFound',
      'rateLimit',
      'server',
      'unexpected',
    });
  });

  test('isTimeout отличает таймаут от обрыва сети', () {
    expect(const NetworkException().isTimeout, isFalse);
    expect(const NetworkException.timeout().isTimeout, isTrue);
  });

  test('toString содержит тип и текст', () {
    expect(const NotFoundException().toString(), contains('NotFoundException'));
    expect(const NotFoundException().toString(), contains('не найден'));
  });
}
