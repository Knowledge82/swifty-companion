/// Characters allowed in a 42 login. This is our assumption: logins in the
/// intra consist of Latin letters, digits and hyphens. If the real set turns
/// out to be wider, the server still answers 404 and we simply show "not
/// found".
final RegExp _loginPattern = RegExp(r'^[a-z0-9_-]+$');

/// Brings the input to the form in which the login goes into the request:
/// no spaces at the edges and in lower case.
String normalizeLogin(String raw) => raw.trim().toLowerCase();

/// What is wrong with the entered login. No user-facing texts are stored here:
/// the interface chooses them by language (`AppStrings.loginProblemText`).
enum LoginProblem { empty, invalidChars }

/// Returns the problem, or `null` if the login is fit for a request. The check
/// exists so that we do not spend a network request on obvious junk and do not
/// put arbitrary characters (`/`, `?`, `..`) into the request address.
LoginProblem? validateLogin(String raw) {
  final login = normalizeLogin(raw);
  if (login.isEmpty) {
    return LoginProblem.empty;
  }
  if (!_loginPattern.hasMatch(login)) {
    return LoginProblem.invalidChars;
  }
  return null;
}
