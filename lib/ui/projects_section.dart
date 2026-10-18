import 'package:flutter/material.dart';

import '../core/display.dart';
import '../l10n/app_strings.dart';
import '../models/project_category.dart';
import '../models/project_result.dart';
import 'section_title.dart';

/// Раздел «Проекты»: завершённые проекты (сданные и проваленные), разложенные
/// по группам Outer Core, Common Core, Piscina. Пустые группы не показываются.
/// Результат передаётся значком, цветом **и** словом, чтобы не зависеть от цвета.
class ProjectsSection extends StatelessWidget {
  const ProjectsSection({super.key, required this.groups});

  final Map<ProjectCategory, List<ProjectResult>> groups;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final nonEmpty = [
      for (final category in ProjectCategory.values)
        if (groups[category]?.isNotEmpty ?? false) category,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(strings.projectsTitle),
        if (nonEmpty.isEmpty)
          Text(strings.projectsEmpty)
        else
          for (final category in nonEmpty) ...[
            _GroupHeading(
              title: strings.projectCategoryTitle(category),
              count: groups[category]!.length,
            ),
            for (final project in groups[category]!) _ProjectRow(project: project),
          ],
      ],
    );
  }
}

class _GroupHeading extends StatelessWidget {
  const _GroupHeading({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 2),
      child: Row(
        children: [
          Icon(Icons.settings, size: 16, color: colors.secondary),
          const SizedBox(width: 6),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                '$title · $count',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectRow extends StatelessWidget {
  const _ProjectRow({required this.project});

  final ProjectResult project;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final colors = Theme.of(context).colorScheme;

    final (IconData icon, Color color, String label) = switch (project.outcome) {
      ProjectOutcome.passed => (
          Icons.check_circle,
          colors.tertiary,
          strings.projectPassed,
        ),
      ProjectOutcome.failed => (
          Icons.cancel,
          colors.error,
          strings.projectFailed,
        ),
      ProjectOutcome.unknown => (
          Icons.help_outline,
          colors.outline,
          strings.projectUnknown,
        ),
    };
    final date = project.date;
    final subtitle = date == null ? label : '$label · ${formatDate(date)}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(project.name ?? strings.unnamed),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(project.finalMark.orNA),
        ],
      ),
    );
  }
}
