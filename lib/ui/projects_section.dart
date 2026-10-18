import 'package:flutter/material.dart';

import '../core/display.dart';
import '../l10n/app_strings.dart';
import '../models/project_category.dart';
import '../models/project_result.dart';
import 'section_title.dart';

/// Раздел «Проекты»: завершённые проекты (сданные и проваленные), разложенные
/// по группам Outer Core, Common Core, Piscina. Пустые группы не показываются.
///
/// Каждая группа **свёрнута** и раскрывается по касанию на заголовок: список
/// из 40 проектов целиком забил бы экран. Какие группы раскрыты, помнит
/// состояние этого виджета (пока открыт профиль).
/// Результат передаётся значком, цветом **и** словом, чтобы не зависеть от цвета.
class ProjectsSection extends StatefulWidget {
  const ProjectsSection({super.key, required this.groups});

  final Map<ProjectCategory, List<ProjectResult>> groups;

  @override
  State<ProjectsSection> createState() => _ProjectsSectionState();
}

class _ProjectsSectionState extends State<ProjectsSection> {
  final Set<ProjectCategory> _expanded = {};

  void _toggle(ProjectCategory category) {
    setState(() {
      if (!_expanded.remove(category)) {
        _expanded.add(category);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final nonEmpty = [
      for (final category in ProjectCategory.values)
        if (widget.groups[category]?.isNotEmpty ?? false) category,
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
              count: widget.groups[category]!.length,
              expanded: _expanded.contains(category),
              onTap: () => _toggle(category),
            ),
            _Collapsible(
              expanded: _expanded.contains(category),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final project in widget.groups[category]!)
                    _ProjectRow(project: project),
                ],
              ),
            ),
          ],
      ],
    );
  }
}

/// Заголовок группы: нажимается целиком, справа стрелка, которая
/// поворачивается при раскрытии.
class _GroupHeading extends StatelessWidget {
  const _GroupHeading({
    required this.title,
    required this.count,
    required this.expanded,
    required this.onTap,
  });

  final String title;
  final int count;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // Material с прозрачным типом нужен, чтобы волна от касания рисовалась
    // ПОВЕРХ панели: иначе она рисовалась бы на Material экрана, под панелью,
    // и была бы не видна.
    return Material(
      type: MaterialType.transparency,
      child: Semantics(
        button: true,
        header: true,
        expanded: expanded,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: ConstrainedBox(
            // 48 пикселей: минимальный удобный размер для пальца.
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              children: [
                Icon(Icons.settings, size: 16, color: colors.secondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '$title · $count',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.expand_more, color: colors.primary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Плавно раскрывающийся блок. Пока блок полностью свёрнут, содержимое
/// **не строится** в дереве виджетов (ни одной строки списка).
class _Collapsible extends StatefulWidget {
  const _Collapsible({required this.expanded, required this.child});

  final bool expanded;
  final Widget child;

  @override
  State<_Collapsible> createState() => _CollapsibleState();
}

class _CollapsibleState extends State<_Collapsible>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: widget.expanded ? 1 : 0,
  );
  late final Animation<double> _size = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );

  @override
  void didUpdateWidget(_Collapsible oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expanded != oldWidget.expanded) {
      if (widget.expanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        if (_controller.isDismissed) {
          return const SizedBox(width: double.infinity);
        }
        return SizeTransition(
          sizeFactor: _size,
          alignment: Alignment.topCenter,
          child: child,
        );
      },
      child: widget.child,
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
