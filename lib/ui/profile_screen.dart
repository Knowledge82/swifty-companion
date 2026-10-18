import 'package:flutter/material.dart';

import '../core/display.dart';
import '../l10n/app_strings.dart';
import '../models/user_profile.dart';
import 'profile_avatar.dart';

/// Экран 2: данные студента. Пока основные поля; скиллы и проекты
/// добавятся на следующем этапе. Кнопка «назад» в AppBar возвращает на экран 1.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final cursus = profile.mainCursus;
    return Scaffold(
      appBar: AppBar(title: Text(profile.login)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: ProfileAvatar(
                      urls: profile.imageUrls,
                      initials: initialsOf(profile.displayName ?? profile.login),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    profile.displayName.orNA,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 24),
                  _InfoRow(label: strings.emailLabel, value: profile.email.orNA),
                  _InfoRow(label: strings.phoneLabel, value: profile.phone.orNA),
                  _InfoRow(label: strings.locationLabel, value: profile.location.orNA),
                  _InfoRow(
                    label: strings.levelLabel,
                    value: cursus == null ? notAvailable : formatLevel(cursus.level),
                  ),
                  _InfoRow(label: strings.walletLabel, value: profile.wallet.orNA),
                  _InfoRow(
                    label: strings.correctionPointsLabel,
                    value: profile.correctionPoints.orNA,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
