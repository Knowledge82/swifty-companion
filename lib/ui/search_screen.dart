import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/api_exception.dart';
import '../core/login.dart';
import '../data/photo_loader.dart';
import '../data/user_repository.dart';
import '../l10n/app_strings.dart';
import 'error_banner.dart';
import 'profile_screen.dart';

/// Экран 1: поле логина, кнопка поиска, индикатор загрузки, сообщение об ошибке.
///
/// Состояния экрана:
/// - ожидание: поле и кнопка активны;
/// - загрузка (`_loading`): кнопка показывает индикатор и не нажимается;
/// - ошибка ввода (`_fieldError`): красный текст под полем, запрос не отправлялся;
/// - ошибка запроса (`_requestError`): баннер под кнопкой;
/// - успех: открывается экран профиля.
class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.repository,
    required this.photoLoader,
  });

  final UserRepository repository;
  final PhotoLoader photoLoader;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();

  bool _loading = false;
  LoginProblem? _fieldError;
  ApiException? _requestError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Защита от двойного нажатия, пока предыдущий запрос не закончился.
    if (_loading) {
      return;
    }

    final raw = _controller.text;
    final validation = validateLogin(raw);
    if (validation != null) {
      setState(() {
        _fieldError = validation;
        _requestError = null;
      });
      return;
    }

    setState(() {
      _fieldError = null;
      _requestError = null;
      _loading = true;
    });

    try {
      final profile = await widget.repository.fetchUser(raw);
      // Пока шёл запрос, экран мог быть закрыт: после await к context
      // можно обращаться, только убедившись, что виджет ещё в дереве.
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ProfileScreen(
            profile: profile,
            loadPhoto: widget.photoLoader.load,
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _requestError = e;
        _loading = false;
      });
    } catch (e, stackTrace) {
      // Сюда попадает только ошибка в нашем коде. Пользователю показываем
      // общее сообщение, а в отладке выводим подробности.
      if (kDebugMode) {
        debugPrint('Непредвиденная ошибка: $e\n$stackTrace');
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _requestError = const UnexpectedResponseException();
        _loading = false;
      });
    }
  }

  void _clearErrors() {
    if (_fieldError != null || _requestError != null) {
      setState(() {
        _fieldError = null;
        _requestError = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final requestError = _requestError;
    final fieldError = _fieldError;
    return Scaffold(
      appBar: AppBar(title: Text(strings.appTitle)),
      body: SafeArea(
        child: Center(
          // Прокрутка спасает от переполнения, когда открыта клавиатура
          // или экран повёрнут.
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _controller,
                    enabled: !_loading,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.search,
                    onChanged: (_) => _clearErrors(),
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: strings.loginLabel,
                      errorText: fieldError == null
                          ? null
                          : strings.loginProblemText(fieldError),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(strings.searchButton),
                  ),
                  if (requestError != null) ...[
                    const SizedBox(height: 16),
                    ErrorBanner(error: requestError),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
