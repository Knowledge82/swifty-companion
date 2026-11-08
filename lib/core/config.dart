/// Configuration error: required values are missing from `.env`.
class ConfigException implements Exception {
  const ConfigException(this.message, {this.missing = const []});

  final String message;

  /// Names of the variables that are missing.
  final List<String> missing;

  @override
  String toString() => 'ConfigException: $message';
}

/// App secrets from `.env`: the identifier and secret issued by the intra.
class AppConfig {
  const AppConfig({required this.clientId, required this.clientSecret});

  /// Parses a map of variables (in the app this is `dotenv.env`).
  ///
  /// It takes a plain `Map` and does not touch `dotenv` directly, so it can be
  /// tested without Flutter and without a real `.env`.
  factory AppConfig.fromMap(Map<String, String> env) {
    final id = env['FT_UID']?.trim() ?? '';
    final secret = env['FT_SECRET']?.trim() ?? '';

    final missing = <String>[
      if (id.isEmpty) 'FT_UID',
      if (secret.isEmpty) 'FT_SECRET',
    ];
    if (missing.isNotEmpty) {
      throw ConfigException(
        'Missing values in .env: ${missing.join(', ')}',
        missing: missing,
      );
    }
    return AppConfig(clientId: id, clientSecret: secret);
  }

  final String clientId;
  final String clientSecret;

  /// The values are hidden so that the secret cannot leak into a log via
  /// `print(config)`.
  @override
  String toString() => 'AppConfig(clientId: ***, clientSecret: ***)';
}
