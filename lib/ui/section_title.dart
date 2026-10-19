import 'package:flutter/material.dart';

import 'steampunk/steampunk_theme.dart';

/// Заголовок раздела на экране профиля: латунная шестерёнка, текст цвета
/// окиси ([sectionTitleColor]) и линия.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.settings, color: colors.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    text,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: sectionTitleColor,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Divider(height: 1, thickness: 1, color: colors.outlineVariant),
        ],
      ),
    );
  }
}
