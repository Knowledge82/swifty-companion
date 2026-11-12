import 'package:flutter/foundation.dart';		// debugPrint, kDebugMode
import 'package:flutter_dotenv/flutter_dotenv.dart';	// read .env
import 'package:material_ui/material_ui.dart';			// runApp, MaterialApp, StatelessWidget

import 'core/api_client.dart';
import 'core/config.dart';
import 'core/token_service.dart';
import 'data/photo_loader.dart';
import 'data/user_repository.dart';
import 'l10n/app_strings.dart';
import 'ui/config_error_screen.dart';
import 'ui/search_screen.dart';
import 'ui/splash_screen.dart';
import 'ui/steampunk/steampunk_theme.dart';

Future<void> main() async {
  // vinculamos Dart con plataforma (Android en nuestro caso)
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
    final config = AppConfig.fromMap(dotenv.env);
    // Only the fact of loading; secret values are never written to the log.
    // Under `kDebugMode`, like the rest of the technical log: a release build
    // stays silent (`debugPrint` is not removed from a release build).
    if (kDebugMode) {
      debugPrint('Config loaded');
    }
    final deps = _buildDependencies(config);
    runApp(SwiftyApp(repository: deps.repository, photoLoader: deps.photos));
  } on ConfigException catch (e) {
    runApp(ConfigErrorApp(missingKeys: e.missing));
  } catch (error, stackTrace) {
    // Anything else (an unreadable `.env`, a bug in the startup code) ends
    // with the same "cannot read the configuration" screen, but the real cause
    // must not vanish. In a debug build we print where it failed: the type of
    // the error and the stack trace. The message text is deliberately NOT
    // printed: we do not control what a library puts into it, and a log must
    // never contain secrets.
    if (kDebugMode) {
      debugPrint('Startup failed: ${error.runtimeType}\n$stackTrace');
    }
    runApp(const ConfigErrorApp(unreadable: true));
  }
}

/// Assembles the dependencies: one `TokenService` for the whole app, with the
/// API client (profile) and the photo loader on top of it. The token is shared
/// and requested once.
({UserRepository repository, PhotoLoader photos}) _buildDependencies(
  AppConfig config,
) {
  // In a debug build we write a technical log to the console (no secrets);
  // in a release build we stay silent.
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
    // The search screen is the same in both branches below, so it is created
    // once. It is a local variable and not a field: a field initializer cannot
    // use other fields (`repository`), and a class with a `const` constructor
    // may only have final fields that are constants or constructor parameters.
    final search = SearchScreen(
      repository: repository,
      photoLoader: photoLoader,
    );
    return MaterialApp(
      onGenerateTitle: (context) => AppStrings.of(context).appTitle,
      localizationsDelegates: AppStrings.localizationsDelegates,
      supportedLocales: AppStrings.supportedLocales,
      theme: buildSteampunkTheme(),
      home: introEnabled ? SplashScreen(next: search) : search,
    );
  }
}
