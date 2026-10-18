import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/api_client.dart';
import 'core/config.dart';
import 'core/token_service.dart';
import 'data/user_repository.dart';
import 'l10n/app_strings.dart';
import 'ui/config_error_screen.dart';
import 'ui/search_screen.dart';

Future<void> main() async {
  // Нужно, чтобы вызывать платформенный код (чтение ассета) до runApp.
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
    final config = AppConfig.fromMap(dotenv.env);
    // Только факт загрузки; значения секретов в лог не выводим никогда.
    debugPrint('Конфиг загружен');
    runApp(SwiftyApp(repository: _buildRepository(config)));
  } on ConfigException catch (e) {
    runApp(ConfigErrorApp(missingKeys: e.missing));
  } catch (_) {
    runApp(const ConfigErrorApp(unreadable: true));
  }
}

/// Собирает цепочку зависимостей: токен → клиент API → репозиторий.
/// Один экземпляр на всё приложение, поэтому токен общий и запрашивается один раз.
UserRepository _buildRepository(AppConfig config) {
  // В отладочной сборке пишем технический журнал в консоль (без секретов),
  // в релизной молчим.
  final void Function(String)? log = kDebugMode ? debugPrint : null;
  final tokens = TokenService(config: config, onLog: log);
  final api = ApiClient(tokenService: tokens, onLog: log);
  return UserRepository(api);
}

class SwiftyApp extends StatelessWidget {
  const SwiftyApp({super.key, required this.repository});

  final UserRepository repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppStrings.of(context).appTitle,
      localizationsDelegates: AppStrings.localizationsDelegates,
      supportedLocales: AppStrings.supportedLocales,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: SearchScreen(repository: repository),
    );
  }
}
