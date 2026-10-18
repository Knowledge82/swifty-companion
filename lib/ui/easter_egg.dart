import 'package:flutter/material.dart';

import 'steampunk/steampunk_theme.dart';

/// Пасхалки: у некоторых логинов под именем появляется своя надпись.
///
/// Выключатель: поставь [easterEggsEnabled] в `false`, и они исчезнут
/// (например, перед защитой проекта). Надписи не переводятся: это шутка,
/// а не часть интерфейса.
const bool easterEggsEnabled = true;

const Map<String, String> _banners = {
  'vdarsuye': 'EL PUTO AMO',
  'pdoltu': 'ЙЕБАНИСТА',
};

/// Надпись для логина или `null`. Логины в API в нижнем регистре,
/// но сравниваем без учёта регистра и пробелов, на всякий случай.
String? easterEggFor(String login) =>
    easterEggsEnabled ? _banners[login.trim().toLowerCase()] : null;

/// Латунная «табличка» с шестерёнками по бокам.
class EasterEggBadge extends StatelessWidget {
  const EasterEggBadge({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: emeraldDeep,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.primary, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.settings, size: 18, color: colors.tertiary),
            const SizedBox(width: 8),
            // FittedBox уменьшает надпись, если она не помещается
            // (узкий экран, крупный системный шрифт).
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  text,
                  maxLines: 1,
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.settings, size: 18, color: colors.tertiary),
          ],
        ),
      ),
    );
  }
}
