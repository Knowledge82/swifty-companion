import 'package:flutter/material.dart';

import '../core/display.dart';
import '../l10n/app_strings.dart';
import '../models/skill.dart';
import 'section_title.dart';

/// Раздел «Скиллы»: название, уровень, процент и полоса прогресса.
class SkillsSection extends StatelessWidget {
  const SkillsSection({super.key, required this.skills});

  final List<Skill> skills;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    // Сильные скиллы сверху; при равных уровнях порядок по названию.
    final sorted = [...skills]..sort((a, b) {
        final byLevel = b.level.compareTo(a.level);
        return byLevel != 0 ? byLevel : (a.name ?? '').compareTo(b.name ?? '');
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(strings.skillsTitle),
        if (sorted.isEmpty)
          Text(strings.skillsEmpty)
        else ...[
          for (final skill in sorted) _SkillRow(skill: skill),
          const SizedBox(height: 4),
          Text(
            strings.skillsFormulaNote(maxSkillLevel.round()),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ],
    );
  }
}

class _SkillRow extends StatelessWidget {
  const _SkillRow({required this.skill});

  final Skill skill;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final name = skill.name ?? strings.unnamed;
    final percent = formatPercent(skill.percent);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Wrap вместо Row: при крупном шрифте или длинном названии уровень
          // переходит на следующую строку, а не вылезает за край экрана.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 2,
            children: [
              Text(name),
              Text('${formatLevel(skill.level)} · $percent'),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: skill.percent / 100,
              minHeight: 8,
              semanticsLabel: name,
              semanticsValue: percent,
            ),
          ),
        ],
      ),
    );
  }
}
