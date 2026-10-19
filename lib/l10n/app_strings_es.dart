import 'app_strings.dart';

/// Испанский (Испания). Язык интерфейса по умолчанию.
class AppStringsEs extends AppStrings {
  const AppStringsEs();

  @override
  String get appTitle => 'Swifty Companion';

  @override
  String get loginLabel => 'Login de 42';
  @override
  String get searchButton => 'Buscar';
  @override
  String get loginEmptyError => 'Introduce un login';
  @override
  String get loginInvalidError =>
      'Solo letras latinas, números, «-» y «_»';

  @override
  String get networkError =>
      'Sin conexión a internet. Comprueba tu red e inténtalo de nuevo.';
  @override
  String get timeoutError =>
      'El servidor no respondió a tiempo. Inténtalo de nuevo más tarde.';
  @override
  String get authError =>
      'No se pudo autenticar en la API de 42. Comprueba las claves del archivo .env.';
  @override
  String get notFoundError => 'No se ha encontrado ningún usuario con ese login.';
  @override
  String get rateLimitError =>
      'Demasiadas peticiones. Espera un momento e inténtalo de nuevo.';
  @override
  String retryAfterHint(int seconds) => 'Puedes reintentar en $seconds s.';
  @override
  String get serverError =>
      'El servidor de la API de 42 no está disponible ahora. Inténtalo más tarde.';
  @override
  String get unexpectedError => 'Se recibió una respuesta inesperada del servidor.';

  @override
  String get emailLabel => 'Correo';
  @override
  String get phoneLabel => 'Teléfono';
  // Puesto: "puesto de trabajo" (ordenador concreto del campus, p. ej. c1r2s3).
  @override
  String get locationLabel => 'Puesto';
  @override
  String get onlineLabel => 'Online';
  @override
  String get onlineOn => 'En el campus';
  @override
  String get onlineOff => 'Fuera del campus';
  @override
  String get levelLabel => 'Nivel';
  @override
  String get walletLabel => 'Monedero';
  @override
  String get correctionPointsLabel => 'Puntos de evaluación';

  @override
  String get skillsTitle => 'Habilidades';
  @override
  String get skillsEmpty => 'Sin habilidades todavía';
  @override
  String skillsFormulaNote(int maxLevel) =>
      'Porcentaje calculado: nivel ÷ $maxLevel (la API no lo da)';
  @override
  String get projectsTitle => 'Proyectos completados';
  @override
  String get projectsEmpty => 'Aún no hay proyectos completados';
  @override
  String get projectsOuterCore => 'Outer Core';
  @override
  String get projectsCommonCore => 'Common Core';
  @override
  String get projectsPiscine => 'Piscina';
  @override
  String get projectsPiscineReloaded => 'Piscina Reloaded';
  @override
  String get projectPassed => 'Aprobado';
  @override
  String get projectFailed => 'Suspendido';
  @override
  String get projectUnknown => 'Sin resultado';
  @override
  String get unnamed => 'Sin nombre';

  @override
  String get configErrorTitle => 'Error de configuración';
  @override
  String configMissing(List<String> keys) =>
      'Faltan valores en .env: ${keys.join(', ')}';
  @override
  String get configUnreadable => 'No se pudo leer el archivo .env de los assets';
  @override
  String get configHint =>
      'Copia .env.example a .env, rellena FT_UID y FT_SECRET y vuelve a compilar la app.';
}
