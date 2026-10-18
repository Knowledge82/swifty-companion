import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'gears.dart';
import 'pipes.dart';
import 'steampunk_theme.dart';
import 'wear.dart';

/// Толщина латунного кольца вокруг фото по умолчанию.
const double brassRingThickness = 13;

/// Цвета фона по умолчанию: тёмная кожа.
const List<Color> backdropColors = [leather, leatherDeep];

/// Фон экрана: тёмная кожа с лёгким светом в центре, слабым узором шестерёнок,
/// трубами и кабелями по краям и большой медленно вращающейся шестерней,
/// которая на четверть выглядывает из правого нижнего угла.
///
/// Узор, трубы и кабели рисуются один раз и закрыты `RepaintBoundary`, поэтому
/// прокрутка содержимого их не перерисовывает. Вращается только угловая
/// шестерня (и она не вращается при включённом «убрать анимации»).
class SteampunkBackdrop extends StatelessWidget {
  const SteampunkBackdrop({
    super.key,
    required this.child,
    this.colors = backdropColors,
  });

  final Widget child;

  /// Два цвета радиального градиента: в центре и по краям.
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Stack(
      // expand: содержимое получает весь экран, а не «сколько ему нужно».
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
              // Радиус зависит от экрана, но в разумных пределах.
              final radius = (shortest * 0.46).clamp(100.0, 260.0).toDouble();
              return Stack(
                // Всё, что вылезает за экран, обрезается: нужна только четверть.
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

/// Изумрудная панель в латунной раме: потёртая рамка с пятнами окиси,
/// медная вставка внутри и клёпки по всему периметру.
/// Фон чуть прозрачный, чтобы шестерёнки позади угадывались.
/// `RepaintBoundary` хранит нарисованную панель готовой картинкой, поэтому
/// при прокрутке клёпки и пятна не перерисовываются.
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
          border: Border.all(color: colors.primary, width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x99000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: CustomPaint(
          // painter рисует ПОД содержимым (износ), foregroundPainter ПОВЕРХ
          // (клёпки): износ не должен закрывать текст, а клёпки лежат в отступе.
          painter: const _WearPainter(),
          foregroundPainter: _RivetPainter(brassColor: colors.primary),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Износ панели: медная вставка, пятна окиси в углах и вдоль краёв, царапины.
/// Случайность детерминирована размером панели: у панели одного размера
/// узор всегда один и тот же, и он не «дрожит» при перерисовке.
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

    // Всё, что рисуется ниже, обрезается по скруглённому контуру панели
    // (чуть внутрь от рамки): у пятен размытый край, и без обрезки он
    // «светился» бы за рамкой.
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(
        (Offset.zero & size).deflate(1.5),
        const Radius.circular(8.5),
      ),
    );

    // Медная вставка: тонкая линия внутри рамки.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        (Offset.zero & size).deflate(5),
        const Radius.circular(6),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = copper.withValues(alpha: 0.6),
    );

    // Окись скапливается в углах.
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

    // И немного вдоль краёв, как подтёки.
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

    // Царапины вдоль рамки: светлые короткие штрихи.
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

/// Клёпки: крупные в углах, средние через каждые ~44 пикселя по периметру.
/// Все латунные: окись на клёпках не рисуется.
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
      drawRivet(canvas, p, 6, body: brassColor);
    }

    void along(Offset from, Offset to) {
      final length = (to - from).distance;
      final gaps = math.max(1, (length / _spacing).round());
      for (var i = 1; i < gaps; i++) {
        drawRivet(canvas, Offset.lerp(from, to, i / gaps)!, 3.6, body: brassColor);
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

/// Латунное кольцо вокруг круглого фото: градиент латуни в медь, тень и
/// клёпки по кругу (через каждые ~40 пикселей). Полный размер = размер фото + 2 × [thickness].
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

/// Простая латунная линия под AppBar (подставляется в `AppBar.bottom`):
/// полоса латуни со светлой верхней кромкой, медной нижней и мягкой тенью.
/// Ни клёпок, ни узора: узор мы пока заменили простой линией.
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
