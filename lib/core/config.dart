/// Ошибка конфигурации: в `.env` нет обязательных значений.
class ConfigException implements Exception {
  const ConfigException(this.message);

  final String message;

  @override
  String toString() => 'ConfigException: $message';
}

/// Секреты приложения из `.env`: идентификатор и секрет, выданные интрой.
class AppConfig {
  const AppConfig({required this.clientId, required this.clientSecret});

  /// Разбирает словарь переменных (в приложении это `dotenv.env`).
  ///
  /// Принимает обычный `Map`, а не обращается к `dotenv` напрямую,
  /// поэтому проверяется тестами без Flutter и без настоящего `.env`.
  factory AppConfig.fromMap(Map<String, String> env) {
    final id = env['FT_UID']?.trim() ?? '';
    final secret = env['FT_SECRET']?.trim() ?? '';

    final missing = <String>[
      if (id.isEmpty) 'FT_UID',
      if (secret.isEmpty) 'FT_SECRET',
    ];
    if (missing.isNotEmpty) {
      throw ConfigException('В .env не заполнено: ${missing.join(', ')}');
    }
    return AppConfig(clientId: id, clientSecret: secret);
  }

  final String clientId;
  final String clientSecret;

  /// Значения скрыты, чтобы секрет не попал в лог через `print(config)`.
  @override
  String toString() => 'AppConfig(clientId: ***, clientSecret: ***)';
}
