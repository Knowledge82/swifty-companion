import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'steampunk_theme.dart';

/// Контур шестерёнки: [teeth] зубьев вокруг [center], отверстие посередине.
///
/// Каждый зуб это трапеция: две точки у «корня» (радиус 0.8 от внешнего)
/// и две на вершине. Отверстие добавлено в тот же контур с правилом
/// `evenOdd`, поэтому при заливке в центре остаётся дырка.
Path gearPath({
  required Offset center,
  required double radius,
  required int teeth,
  double rotation = 0,
  double holeRatio = 0.28,
}) {
  final path = Path()..fillType = PathFillType.evenOdd;
  final root = radius * 0.80;
  final step = 2 * math.pi / teeth;
  var first = true;

  for (var i = 0; i < teeth; i++) {
    final a = rotation + i * step;
    final points = <(double, double)>[
      (a - step * 0.30, root),
      (a - step * 0.17, radius),
      (a + step * 0.17, radius),
      (a + step * 0.30, root),
    ];
    for (final (angle, r) in points) {
      final p = center + Offset(math.cos(angle), math.sin(angle)) * r;
      if (first) {
        path.moveTo(p.dx, p.dy);
        first = false;
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
  }
  path.close();
  path.addOval(Rect.fromCircle(center: center, radius: radius * holeRatio));
  return path;
}

/// Узор из полупрозрачных шестерёнок на всю площадь.
///
/// Раскладка детерминирована (фиксированное зерно `seed`): холст делится на
/// клетки по 150 пикселей, в каждой (кроме случайно пропущенных) рисуется
/// шестерёнка случайного размера, с случайным числом зубьев и поворотом.
/// Узор статичный: без анимации он ничего не стоит процессору и не мешает
/// `pumpAndSettle` в тестах.
class GearsPainter extends CustomPainter {
  const GearsPainter({required this.color, this.seed = 42});

  final Color color;
  final int seed;

  static const double _cell = 150;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final random = math.Random(seed);
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: 0.06);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = color.withValues(alpha: 0.16);

    final cols = (size.width / _cell).ceil() + 1;
    final rows = (size.height / _cell).ceil() + 1;

    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        // Случайные числа тратим в одном порядке для каждой клетки, чтобы
        // пропуск одной клетки не сдвигал узор во всех следующих.
        final skip = random.nextDouble() < 0.25;
        final dx = random.nextDouble();
        final dy = random.nextDouble();
        final radius = 30 + random.nextDouble() * 50;
        final teeth = 8 + random.nextInt(9);
        final rotation = random.nextDouble() * 2 * math.pi;
        if (skip) {
          continue;
        }
        final center = Offset((col + 0.2 + 0.6 * dx) * _cell, (row + 0.2 + 0.6 * dy) * _cell);
        final path = gearPath(
          center: center,
          radius: radius,
          teeth: teeth,
          rotation: rotation,
        );
        canvas.drawPath(path, fill);
        canvas.drawPath(path, stroke);
        canvas.drawCircle(center, radius * 0.55, stroke);
      }
    }
  }

  @override
  bool shouldRepaint(GearsPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.seed != seed;
}

/// Эмблема: три сцепленные латунные шестерёнки. Чисто декоративная.
class GearEmblem extends StatelessWidget {
  const GearEmblem({super.key, this.size = 120});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: const _EmblemPainter(),
      ),
    );
  }
}

class _EmblemPainter extends CustomPainter {
  const _EmblemPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final rect = Offset.zero & size;
    final fill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFE6C878), brass, copper],
      ).createShader(rect);
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.015
      ..color = leatherDeep;

    // Малые шестерёнки повёрнуты на пол-зуба, чтобы зубья входили во впадины.
    final gears = <(Offset, double, int, double)>[
      (Offset(s * 0.42, s * 0.52), s * 0.34, 14, 0),
      (Offset(s * 0.80, s * 0.28), s * 0.17, 8, math.pi / 8),
      (Offset(s * 0.76, s * 0.80), s * 0.14, 7, math.pi / 7),
    ];
    for (final (center, radius, teeth, rotation) in gears) {
      final path = gearPath(
        center: center,
        radius: radius,
        teeth: teeth,
        rotation: rotation,
        holeRatio: 0.32,
      );
      canvas.drawPath(path, fill);
      canvas.drawPath(path, edge);
      canvas.drawCircle(center, radius * 0.58, edge);
    }
  }

  @override
  bool shouldRepaint(_EmblemPainter oldDelegate) => false;
}
