import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/api_client.dart';
import 'core/config.dart';
import 'core/token_service.dart';
import 'data/photo_loader.dart';
import 'data/user_repository.dart';
import 'l10n/app_strings.dart';
import 'ui/config_error_screen.dart';
import 'ui/search_screen.dart';
import 'ui/steampunk/steampunk_theme.dart';

Future<void> main() async {
  // Нужно, чтобы вызывать платформенный код (чтение ассета) до runApp.
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
    final config = AppConfig.fromMap(dotenv.env);
    // Только факт загрузки; значения секретов в лог не выводим никогда.
    debugPrint('Конфиг загружен');
    final deps = _buildDependencies(config);
    runApp(SwiftyApp(repository: deps.repository, photoLoader: deps.photos));
  } on ConfigException catch (e) {
    runApp(ConfigErrorApp(missingKeys: e.missing));
  } catch (_) {
    runApp(const ConfigErrorApp(unreadable: true));
  }
}

/// Собирает зависимости: один `TokenService` на всё приложение, на нём
/// клиент API (профиль) и загрузчик фото. Токен общий и запрашивается один раз.
({UserRepository repository, PhotoLoader photos}) _buildDependencies(
  AppConfig config,
) {
  // В отладочной сборке пишем технический журнал в консоль (без секретов),
  // в релизной молчим.
  final void Function(String)? log = kDebugMode ? debugPrint : null;
  final tokens = TokenService(config: config, onLog: log);
  final api = ApiClient(tokenService: tokens, onLog: log);
  return (
    repository: UserRepository(api),
    photos: PhotoLoader(tokenService: tokens, onLog: log),
  );
}

class SwiftyApp extends StatelessWidget {
  const SwiftyApp({
    super.key,
    required this.repository,
    required this.photoLoader,
  });

  final UserRepository repository;
  final PhotoLoader photoLoader;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppStrings.of(context).appTitle,
      localizationsDelegates: AppStrings.localizationsDelegates,
      supportedLocales: AppStrings.supportedLocales,
      theme: buildSteampunkTheme(),
      home: SearchScreen(repository: repository, photoLoader: photoLoader),
    );
  }
}
