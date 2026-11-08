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

/// Photo size on the profile screen (twice as big as in the first version).
const double avatarMaxSize = 224;

/// Screen 2: the student's data. The "back" button in the AppBar returns to
/// screen 1. The content is laid out on brass panels over a background of
/// gears.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.profile,
    required this.loadPhoto,
  });

  final UserProfile profile;

  /// How to download the photo (the CDN needs the token, so a plain
  /// `Image.network` does not work).
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
                // LayoutBuilder: we learn the real width and do not let the
                // photo go beyond it on a very narrow screen (constraints go
                // down).
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
                              // The workstation is shown only if the student is
                              // on campus.
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

/// A bar "how much has been done toward the next level" (the fractional part of
/// the level).
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

/// The "Estado" (status) row: a lamp and a word. A green lamp with a soft glow
/// if the student is on campus, a grey extinguished one if not.
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
