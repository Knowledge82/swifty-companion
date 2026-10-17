import 'package:flutter/material.dart';

import '../core/login.dart';
import 'profile_screen.dart';

/// Экран 1: поле логина и кнопка поиска.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  // Контроллер хранит набранный текст; его нужно освобождать в dispose.
  final TextEditingController _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final raw = _controller.text;
    final error = validateLogin(raw);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() => _error = null);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileScreen(login: normalizeLogin(raw)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Swifty Companion')),
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
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'Логин 42',
                      errorText: _error,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _submit, child: const Text('Найти')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
