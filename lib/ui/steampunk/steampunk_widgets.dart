import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'gears.dart';
import 'pipes.dart';
import 'steampunk_theme.dart';
import 'wear.dart';

/// Default thickness of the brass ring around the photo.
const double brassRingThickness = 13;

/// Default background colors: dark leather.
const List<Color> backdropColors = [leather, leatherDeep];

/// The screen background: dark leather with a soft light in the center, a faint
/// pattern of gears, pipes and cables along the edges and a big slowly rotating
/// gear, a quarter of which peeks out of the bottom right corner.
///
/// The pattern, pipes and cables are drawn once and wrapped in a
/// `RepaintBoundary`, so scrolling the content does not repaint them. Only the
/// corner gear rotates (and it does not rotate when "remove animations" is on).
class SteampunkBackdrop extends StatelessWidget {
  const SteampunkBackdrop({
    super.key,
    required this.child,
    this.colors = backdropColors,
  });

  final Widget child;

  /// The two colors of the radial gradient: in the center and at the edges.
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Stack(
      // expand: the content gets the whole screen, not "as much as it needs".
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.3),
                radius: 1.2,
                colors: colors,
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: ExcludeSemantics(
            child: RepaintBoundary(
              child: CustomPaint(painter: GearsPainter(color: primary)),
            ),
          ),
        ),
        const Positioned.fill(
          child: ExcludeSemantics(
            child: RepaintBoundary(child: CustomPaint(painter: PipesPainter())),
          ),
        ),
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, box) {
              final shortest = math.min(box.maxWidth, box.maxHeight);
              if (!shortest.isFinite) {
                return const SizedBox.shrink();
              }
              // The radius depends on the screen, but within reasonable limits.
              final radius = (shortest * 0.46).clamp(100.0, 260.0).toDouble();
              return Stack(
                // Everything that sticks out past the screen is clipped: only a
                // quarter is needed.
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned(
                    right: -radius,
                    bottom: -radius,
                    child: CornerGear(radius: radius),
                  ),
                ],
              );
            },
          ),
        ),
        child,
      ],
    );
  }
}

/// How "golden" the rivets are: 1 is pure brass, 0 is the panel color. They are
/// muted so as not to compete with progress bars and accents for attention.
const double _rivetStrength = 0.72;

/// A walnut panel in a brass frame: a worn border with oxide stains, a copper
/// inlay inside and rivets all around the perimeter.
/// The background is slightly transparent so that the gears behind can be made
/// out. `RepaintBoundary` keeps the drawn panel as a ready picture, so when
/// scrolling the rivets and stains are not repainted.
class BrassPanel extends StatelessWidget {
  const BrassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(10),
          // The border is thin (1 px, was 1.5): the panel is separated from the
          // background by tone, volume and shadow, not by a bright outline.
          border: Border.all(color: colors.primary, width: 1),
          boxShadow: const [
            BoxShadow(
              color: Color(0xAA000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: CustomPaint(
          // painter draws UNDER the content (wear), foregroundPainter ON TOP of
          // it (rivets): the wear must not cover the text, and the rivets lie
          // in the padding.
          painter: const _WearPainter(),
          foregroundPainter: _RivetPainter(
            brassColor: Color.lerp(colors.surface, colors.primary, _rivetStrength)!,
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Panel wear: a copper inlay, oxide stains in the corners and along the edges,
/// scratches. The randomness is determined by the panel size: for a panel of
/// one size the pattern is always the same, and it does not "jitter" on
/// repaint.
class _WearPainter extends CustomPainter {
  const _WearPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 60 || size.height < 60) {
      return;
    }
    final random = math.Random(size.width.round() * 7919 + size.height.round());
    final w = size.width;
    final h = size.height;

    // Everything drawn below is clipped to the rounded outline of the panel (a
    // bit inside the border): the stains have a blurred edge, and without
    // clipping it would "glow" beyond the border.
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(
        (Offset.zero & size).deflate(1.5),
        const Radius.circular(8.5),
      ),
    );

    // The copper inlay: a thin line inside the border.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        (Offset.zero & size).deflate(5),
        const Radius.circular(6),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = copper.withValues(alpha: 0.3),
    );

    // Volume: a light highlight along the inner edge and a bit brighter along
    // the top one, like the bevel on a metal plate. It is what "lifts" the
    // panel above the background.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        (Offset.zero & size).deflate(1.5),
        const Radius.circular(8.5),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = parchment.withValues(alpha: 0.18),
    );
    canvas.drawLine(
      const Offset(10, 2.5),
      Offset(w - 10, 2.5),
      Paint()
        ..strokeWidth = 1
        ..color = parchment.withValues(alpha: 0.27),
    );

    // Oxide gathers in the corners.
    final corners = <(double, double, double, double)>[
      (0, 0, 1, 1),
      (w, 0, -1, 1),
      (0, h, 1, -1),
      (w, h, -1, -1),
    ];
    for (final (x, y, dx, dy) in corners) {
      for (var i = 0; i < 7; i++) {
        drawBlotch(
          canvas,
          Offset(x + dx * random.nextDouble() * 22, y + dy * random.nextDouble() * 22),
          2.5 + random.nextDouble() * 4.5,
          oxide.withValues(alpha: 0.08 + random.nextDouble() * 0.14),
        );
      }
    }

    // And a little along the edges, like streaks.
    for (var i = 0; i < 5; i++) {
      final x = 30 + random.nextDouble() * (w - 60);
      drawBlotch(
        canvas,
        Offset(x, random.nextDouble() * 5),
        2 + random.nextDouble() * 2.5,
        oxide.withValues(alpha: 0.07 + random.nextDouble() * 0.1),
      );
      drawBlotch(
        canvas,
        Offset(x, h - random.nextDouble() * 5),
        2 + random.nextDouble() * 2.5,
        oxide.withValues(alpha: 0.07 + random.nextDouble() * 0.1),
      );
    }

    // Scratches along the border: light short strokes.
    for (var i = 0; i < 16; i++) {
      final side = random.nextInt(4);
      final along = random.nextDouble();
      final inset = 3 + random.nextDouble() * 9;
      final tilt = (random.nextDouble() - 0.5) * 0.7;
      final length = 6 + random.nextDouble() * 18;
      final color = parchment.withValues(alpha: 0.07 + random.nextDouble() * 0.1);
      switch (side) {
        case 0:
          drawScratch(canvas, Offset(along * w, inset), length, tilt, color);
        case 1:
          drawScratch(canvas, Offset(along * w, h - inset), length, tilt, color);
        case 2:
          drawScratch(canvas, Offset(inset, along * h), length, math.pi / 2 + tilt, color);
        default:
          drawScratch(canvas, Offset(w - inset, along * h), length, math.pi / 2 + tilt, color);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WearPainter oldDelegate) => false;
}

/// Rivets: large in the corners, medium every ~44 pixels along the perimeter.
/// All of them are brass: no oxide is drawn on the rivets.
class _RivetPainter extends CustomPainter {
  const _RivetPainter({required this.brassColor});

  final Color brassColor;

  static const double _inset = 10;
  static const double _spacing = 44;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 60 || size.height < 60) {
      return;
    }
    final w = size.width;
    final h = size.height;

    for (final p in [
      const Offset(_inset, _inset),
      Offset(w - _inset, _inset),
      Offset(_inset, h - _inset),
      Offset(w - _inset, h - _inset),
    ]) {
      drawRivet(canvas, p, 4.2, body: brassColor);
    }

    void along(Offset from, Offset to) {
      final length = (to - from).distance;
      final gaps = math.max(1, (length / _spacing).round());
      for (var i = 1; i < gaps; i++) {
        drawRivet(canvas, Offset.lerp(from, to, i / gaps)!, 2.6, body: brassColor);
      }
    }

    along(const Offset(_inset, _inset), Offset(w - _inset, _inset));
    along(Offset(_inset, h - _inset), Offset(w - _inset, h - _inset));
    along(const Offset(_inset, _inset), Offset(_inset, h - _inset));
    along(Offset(w - _inset, _inset), Offset(w - _inset, h - _inset));
  }

  @override
  bool shouldRepaint(_RivetPainter oldDelegate) =>
      oldDelegate.brassColor != brassColor;
}

/// A brass ring around a round photo: a gradient from brass to copper, a shadow
/// and rivets around the circle (every ~40 pixels). Full size = photo size +
/// 2 × [thickness].
class BrassRing extends StatelessWidget {
  const BrassRing({
    super.key,
    required this.child,
    this.thickness = brassRingThickness,
  });

  final Widget child;
  final double thickness;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _RingRivetPainter(thickness: thickness),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE6C878), brass, copper],
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x99000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Padding(padding: EdgeInsets.all(thickness), child: child),
      ),
    );
  }
}

class _RingRivetPainter extends CustomPainter {
  const _RingRivetPainter({required this.thickness});

  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - thickness / 2;
    if (radius <= 0) {
      return;
    }
    final count = math.max(8, (2 * math.pi * radius / 40).round());
    for (var i = 0; i < count; i++) {
      final angle = 2 * math.pi * i / count;
      drawRivet(
        canvas,
        center + Offset(math.cos(angle), math.sin(angle)) * radius,
        thickness * 0.30,
        body: const Color(0xFFE9CE86),
      );
    }
  }

  @override
  bool shouldRepaint(_RingRivetPainter oldDelegate) =>
      oldDelegate.thickness != thickness;
}

/// A simple brass line under the AppBar (plugged into `AppBar.bottom`): a brass
/// strip with a light top edge, a copper bottom one and a soft shadow.
/// No rivets, no pattern: for now we replaced the pattern with a simple line.
class BrassLine extends StatelessWidget implements PreferredSizeWidget {
  const BrassLine({super.key});

  static const double height = 5;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    return const ExcludeSemantics(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFE6C878), brass, copper],
              stops: [0, 0.55, 1],
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x99000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
