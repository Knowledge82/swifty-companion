import 'package:flutter/material.dart';

import '../core/display.dart';
import '../l10n/app_strings.dart';
import '../models/project_result.dart';
import 'section_title.dart';

/// Раздел «Проекты»: завершённые проекты, сданные и проваленные.
/// Результат передаётся значком, цветом **и** словом, чтобы не зависеть от цвета.
class ProjectsSection extends StatelessWidget {
  const ProjectsSection({super.key, required this.projects});

  final List<ProjectResult> projects;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(strings.projectsTitle),
        if (projects.isEmpty)
          Text(strings.projectsEmpty)
        else
          for (final project in projects) _ProjectRow(project: project),
      ],
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
          Colors.green.shade700,
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
