import 'package:flutter/material.dart';

import '../core/display.dart';
import '../l10n/app_strings.dart';
import '../models/project_category.dart';
import '../models/project_result.dart';
import 'section_title.dart';

/// The "Projects" section: completed projects (passed and failed), laid out in
/// the groups Outer Core, Common Core, Piscina. Empty groups are not shown.
///
/// Every group is **collapsed** and expands on a tap on the header: a list of
/// 40 projects at once would fill the whole screen. Which groups are expanded
/// is remembered by the state of this widget (while the profile is open). The
/// result is conveyed by an icon, a color **and** a word, so it does not depend
/// on color alone.
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

/// Group header: the whole thing is tappable, with an arrow on the right that
/// rotates when it expands.
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
    // A Material with the transparency type is needed so that the ripple of the
    // tap is drawn ON TOP of the panel: otherwise it would be drawn on the
    // screen's Material, under the panel, and would not be visible.
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
            // 48 pixels: the minimum comfortable size for a finger.
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

/// A smoothly expanding block. While the block is fully collapsed, the content
/// is **not built** in the widget tree (not a single list row).
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
