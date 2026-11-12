import 'package:material_ui/material_ui.dart';

import 'steampunk/steampunk_theme.dart';

/// Easter eggs: some logins get their own caption under the name.
///
/// The switch: set [easterEggsEnabled] to `false` and they disappear (for
/// example, before defending the project). The captions are not translated:
/// this is a joke, not part of the interface.
const bool easterEggsEnabled = true;

const Map<String, String> _banners = {
  'vdarsuye': 'EL PUTO AMO',
  'pdoltu': 'ЙЕБАНИСТА',
};

/// The caption for a login, or `null`. Logins in the API are lower case, but we
/// compare ignoring case and spaces, just in case.
String? easterEggFor(String login) =>
    easterEggsEnabled ? _banners[login.trim().toLowerCase()] : null;

/// A brass "plate" with gears on the sides.
class EasterEggBadge extends StatelessWidget {
  const EasterEggBadge({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: walnutDeep,
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
            // FittedBox shrinks the caption if it does not fit
            // (narrow screen, large system font).
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
