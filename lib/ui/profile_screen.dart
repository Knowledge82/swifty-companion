import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/display.dart';
import '../data/photo_loader.dart';
import '../l10n/app_strings.dart';
import '../models/user_profile.dart';
import 'easter_egg.dart';
import 'profile_avatar.dart';
import 'projects_section.dart';
import 'skills_section.dart';
import 'steampunk/steampunk_theme.dart';
import 'steampunk/steampunk_widgets.dart';

/// Размер фото на экране профиля (в два раза больше первой версии).
const double avatarMaxSize = 224;

/// Экран 2: данные студента. Кнопка «назад» в AppBar возвращает на экран 1.
/// Содержимое разложено по латунным панелям на фоне из шестерёнок.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.profile,
    required this.loadPhoto,
  });

  final UserProfile profile;

  /// Как скачать фото (токен нужен CDN, поэтому обычный `Image.network` не годится).
  final PhotoFetcher loadPhoto;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final colors = Theme.of(context).colorScheme;
    final cursus = profile.mainCursus;
    final egg = easterEggFor(profile.login);
    return Scaffold(
      appBar: AppBar(title: Text(profile.login), bottom: const BrassLine()),
      body: SteampunkBackdrop(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                // LayoutBuilder: узнаём реальную ширину и не даём фото
                // выйти за неё на очень узком экране (constraints вниз).
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const ring = brassRingThickness;
                    final avatarSize = math.min(
                      avatarMaxSize,
                      constraints.maxWidth - 2 * ring,
                    );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: BrassRing(
                            thickness: ring,
                            child: ProfileAvatar(
                              urls: profile.imageUrls,
                              loadPhoto: loadPhoto,
                              initials:
                                  initialsOf(profile.displayName ?? profile.login),
                              size: avatarSize,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          profile.displayName.orNA,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        if (egg != null) ...[
                          const SizedBox(height: 10),
                          Center(child: EasterEggBadge(text: egg)),
                        ],
                        const SizedBox(height: 20),
                        BrassPanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _InfoRow(
                                label: strings.emailLabel,
                                value: profile.email.orNA,
                              ),
                              _InfoRow(
                                label: strings.phoneLabel,
                                value: profile.phone.orNA,
                              ),
                              _StatusRow(
                                label: strings.statusLabel,
                                online: profile.isOnline,
                                onText: strings.onlineOn,
                                offText: strings.onlineOff,
                              ),
                              // Рабочее место показываем, только если студент в кампусе.
                              if (profile.location != null)
                                _InfoRow(
                                  label: strings.locationLabel,
                                  value: profile.location!,
                                ),
                              _InfoRow(
                                label: strings.levelLabel,
                                value: cursus == null
                                    ? notAvailable
                                    : formatLevel(cursus.level),
                              ),
                              if (cursus != null) _LevelBar(level: cursus.level),
                              _InfoRow(
                                label: strings.walletLabel,
                                value: profile.wallet.orNA,
                              ),
                              _InfoRow(
                                label: strings.correctionPointsLabel,
                                value: profile.correctionPoints.orNA,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        BrassPanel(
                          child: SkillsSection(skills: cursus?.skills ?? const []),
                        ),
                        const SizedBox(height: 20),
                        BrassPanel(
                          child: ProjectsSection(
                            groups: profile.finishedProjectsByCategory(),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Полоса «сколько пройдено до следующего уровня» (дробная часть уровня).
class _LevelBar extends StatelessWidget {
  const _LevelBar({required this.level});

  final double level;

  @override
  Widget build(BuildContext context) {
    final fraction = levelFraction(level);
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: fraction,
          minHeight: 8,
          semanticsLabel: AppStrings.of(context).levelLabel,
          semanticsValue: formatPercent(fraction * 100),
        ),
      ),
    );
  }
}

/// Строка «Estado» (статус): лампочка и слово. Зелёная лампочка с лёгким свечением, если
/// студент в кампусе, серая погашенная, если нет.
class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.online,
    required this.onText,
    required this.offText,
  });

  final String label;
  final bool online;
  final String onText;
  final String offText;

  @override
  Widget build(BuildContext context) {
    final text = online ? onText : offText;
    return Semantics(
      label: '$label: $text',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 120,
              child: Text(
                label,
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ),
            Container(
              key: const ValueKey('online-lamp'),
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: online ? onlineGreen : offlineGray,
                border: Border.all(color: leatherDeep, width: 1.5),
                boxShadow: online
                    ? [
                        BoxShadow(
                          color: onlineGreen.withValues(alpha: 0.6),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
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
