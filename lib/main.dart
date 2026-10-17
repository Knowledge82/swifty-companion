import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/config.dart';
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
    runApp(SwiftyApp(config: config));
  } on ConfigException catch (e) {
    runApp(ConfigErrorApp(message: e.message));
  } catch (_) {
    runApp(
      const ConfigErrorApp(message: 'Не удалось прочитать файл .env из ассетов'),
    );
  }
}

class SwiftyApp extends StatelessWidget {
  // config пока не используется: он понадобится токен-сервису (этап 3).
  const SwiftyApp({super.key, required this.config});

  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Swifty Companion',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: const SearchScreen(),
    );
  }
}
