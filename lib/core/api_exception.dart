// The parent:

/// All errors of working with the 42 API in one closed (sealed) family.
///
/// `sealed` means: this is an abstract class, and its direct subclasses are
/// declared only in this file. The compiler knows the full list and requires
/// every case to be handled in a `switch`. Forgetting to handle a new kind of
/// error is impossible.
sealed class ApiException implements Exception {
  const ApiException(this.message);

  /// Description for the developer (logs, debugging, tests). The user is not
  /// shown this but the translation from `AppStrings.errorText`, so the
  /// language of the error matches the language of the interface.
  final String message;

  // `$` inserts a value into a string. `runtimeType` is the real type of the
  // object at run time, so the result is, for example,
  // `NetworkException: <message>`.
  @override
  String toString() => '$runtimeType: $message';
}

// The subclasses:

// 1. No network, DNS does not answer, or the server did not respond in time.

// `final class` means "I cannot be extended or implemented outside this file".
// This keeps the family closed, and nobody outside can add their own "network
// error".
final class NetworkException extends ApiException {
  const NetworkException()
      : isTimeout = false,
        super('No internet connection. Check the network and try again.');

  const NetworkException.timeout()
      : isTimeout = true,
        super('The server did not respond in time. Try again later.');

  /// `true` if the network is there but the server did not respond in time.
  /// The interface picks the text based on this flag.
  final bool isTimeout;
}

// 2. The app could not authorize: wrong keys or a rejected token.
final class AuthException extends ApiException {
  const AuthException()
      : super('Could not authorize with the 42 API. Check the keys in .env.');
}

// 3. Login not found (HTTP 404). Used since stage 4.
final class NotFoundException extends ApiException {
  const NotFoundException() : super('User with this login was not found.');
}

// 4. Rate limit exceeded (HTTP 429).
final class RateLimitException extends ApiException {
  const RateLimitException({this.retryAfter})
      : super('Too many requests. Wait a little and try again.');

  /// How long the server asks us to wait (the `Retry-After` header), if it
  /// said.
  final Duration? retryAfter;
}

// 5. The API server is unavailable or broken (HTTP 5xx).
final class ServerException extends ApiException {
  const ServerException()
      : super('The 42 API server is unavailable right now. Try again later.');
}

// 6. A response arrived, but not the one expected: not JSON, required fields
// missing, unexpected status code.
final class UnexpectedResponseException extends ApiException {
  const UnexpectedResponseException()
      : super('Received an unexpected response from the server.');
}
