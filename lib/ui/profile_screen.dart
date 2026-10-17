import 'package:flutter/material.dart';

/// Экран 2. Пока заглушка: настоящий профиль появится на этапе 6.
/// Кнопка «назад» в AppBar возвращает на первый экран сама.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.login});

  final String login;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(login)),
      body: const Center(child: Text('Здесь будет профиль')),
    );
  }
}
