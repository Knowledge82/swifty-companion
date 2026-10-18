import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'gear_motion.dart';
import 'logo42.dart';
import 'steampunk_theme.dart';
import 'wear.dart';

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
/// Примерно каждая третья шестерёнка окислена: рисуется цветом [patina]
/// (зелёным), остальные латунные ([color]).
/// Узор статичный: без анимации он ничего не стоит процессору и не мешает
/// `pumpAndSettle` в тестах.
class GearsPainter extends CustomPainter {
  const GearsPainter({required this.color, this.patina = oxide, this.seed = 42});

  final Color color;
  final Color patina;
  final int seed;

  static const double _cell = 150;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final random = math.Random(seed);
    Paint fillOf(Color c) => Paint()
      ..style = PaintingStyle.fill
      ..color = c.withValues(alpha: 0.07);
    Paint strokeOf(Color c) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = c.withValues(alpha: 0.18);
    final brassFill = fillOf(color);
    final brassStroke = strokeOf(color);
    final oxideFill = fillOf(patina);
    final oxideStroke = strokeOf(patina);

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
        final oxidized = random.nextDouble() < 0.33;
        if (skip) {
          continue;
        }
        final center = Offset(
          (col + 0.2 + 0.6 * dx) * _cell,
          (row + 0.2 + 0.6 * dy) * _cell,
        );
        final path = gearPath(
          center: center,
          radius: radius,
          teeth: teeth,
          rotation: rotation,
        );
        final fill = oxidized ? oxideFill : brassFill;
        final stroke = oxidized ? oxideStroke : brassStroke;
        canvas.drawPath(path, fill);
        canvas.drawPath(path, stroke);
        canvas.drawCircle(center, radius * 0.55, stroke);
      }
    }
  }

  @override
  bool shouldRepaint(GearsPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.patina != patina ||
      oldDelegate.seed != seed;
}

/// Кэш нарисованных картинок: каждая рисуется один раз на данный размер,
/// а дальше только проигрывается (с поворотом). Контур шестерёнки, пятна и
/// царапины не пересчитываются на каждом кадре.
class _PictureCache {
  Size? _size;
  final Map<int, ui.Picture> _pictures = {};

  ui.Picture of(int key, Size size, void Function(Canvas canvas) draw) {
    if (_size != size) {
      _pictures.clear();
      _size = size;
    }
    return _pictures.putIfAbsent(key, () {
      final recorder = ui.PictureRecorder();
      draw(Canvas(recorder));
      return recorder.endRecording();
    });
  }
}

/// Одна шестерёнка эмблемы с уже посчитанным положением и фазой.
@visibleForTesting
class PlacedGear {
  const PlacedGear({
    required this.center,
    required this.radius,
    required this.teeth,
    required this.phase,
    required this.ratio,
  });

  /// Центр и радиус в долях стороны эмблемы (0..1).
  final Offset center;
  final double radius;
  final int teeth;

  /// Начальный поворот, при котором зубья входят во впадины соседа.
  final double phase;

  /// Во сколько раз и в какую сторону крутится относительно большой
  /// (у большой 1, у сцепленных с ней отрицательное: они крутятся навстречу).
  final double ratio;

  bool get isBig => ratio == 1;
}

/// Большая шестерёнка эмблемы (в долях стороны) и число её зубьев.
@visibleForTesting
const double emblemBigRadius = 0.30;
@visibleForTesting
const int emblemBigTeeth = 14;
@visibleForTesting
const Offset emblemBigCenter = Offset(0.40, 0.50);

/// Секунд на один оборот большой шестерёнки эмблемы.
@visibleForTesting
const double emblemRevolutionSeconds = 36;

/// Раскладка пяти шестерёнок: большая в центре и четыре малых вокруг неё.
///
/// Это не «примерно подогнано», а считается:
/// - **расстояние между осями** такое, чтобы вершина зуба одной почти
///   касалась впадины другой: `max(R + 0.8·r, r + 0.8·R) + зазор`
///   (впадина у нас на 0.8 радиуса, см. [gearPath]);
/// - **фаза**: чтобы в точке касания зуб одной приходился на впадину другой,
///   нужно, чтобы сумма «долей зубьев» с обеих сторон давала 0.5. Из этого
///   условия выводится начальный поворот малой шестерёнки;
/// - **скорость**: у сцепленных шестерён скорость обратно пропорциональна
///   числу зубьев и направлена в противоположную сторону. Тогда условие
///   фазы выполняется в любой момент, и зубья не заходят друг на друга.
@visibleForTesting
List<PlacedGear> placeEmblemGears() {
  const children = <(double, double, int)>[
    // (угол от большой в градусах, радиус, число зубьев)
    (-35.0, 0.16, 8),
    (40.0, 0.15, 7),
    (-125.0, 0.13, 6),
    (125.0, 0.12, 6),
  ];
  final result = <PlacedGear>[
    const PlacedGear(
      center: emblemBigCenter,
      radius: emblemBigRadius,
      teeth: emblemBigTeeth,
      phase: 0,
      ratio: 1,
    ),
  ];
  for (final (degrees, radius, teeth) in children) {
    final alpha = degrees * math.pi / 180;
    final distance =
        math.max(emblemBigRadius + 0.8 * radius, radius + 0.8 * emblemBigRadius) + 0.01;
    final center = emblemBigCenter + Offset(math.cos(alpha), math.sin(alpha)) * distance;
    // Доля зубьев большой шестерёнки в направлении на соседа (её фаза 0).
    final toothFractionBig = alpha * emblemBigTeeth / (2 * math.pi);
    final phase =
        alpha + math.pi - (0.5 - toothFractionBig) * 2 * math.pi / teeth;
    result.add(
      PlacedGear(
        center: center,
        radius: radius,
        teeth: teeth,
        phase: phase,
        ratio: -emblemBigTeeth / teeth,
      ),
    );
  }
  return result;
}

final List<PlacedGear> _emblemGears = placeEmblemGears();

/// Эмблема: пять сцепленных латунных шестерёнок с окисью и царапинами,
/// **вращающихся** (если анимации не отключены, см. [GearClock]).
/// На большой шестерёнке изумрудная ступица со знаком школы 42 (она
/// не вращается: знак всегда читается), в малых болты. Чисто декоративная.
class GearEmblem extends StatelessWidget {
  const GearEmblem({super.key, this.size = 120, this.animate = true});

  final double size;

  /// `false`: шестерёнки стоят (например, на скриншоте или в тесте).
  final bool animate;

  /// Секунд на один оборот большой шестерёнки. Малые крутятся быстрее
  /// в соотношении чисел зубьев.
  static const double revolutionSeconds = emblemRevolutionSeconds;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: GearClock(
          enabled: animate,
          builder: (context, seconds) => CustomPaint(
            size: Size.square(size),
            painter: _EmblemPainter(seconds: seconds),
          ),
        ),
      ),
    );
  }
}

class _EmblemPainter extends CustomPainter {
  _EmblemPainter({required this.seconds}) : super(repaint: seconds);

  final ValueListenable<double> seconds;
  final _PictureCache _cache = _PictureCache();

  /// Рисует саму шестерёнку в её собственных координатах (центр в нуле,
  /// без поворота): дальше эту картинку только поворачивают.
  void _recordGear(Canvas canvas, PlacedGear gear, int index, double s) {
    final r = gear.radius * s;
    final path = gearPath(
      center: Offset.zero,
      radius: r,
      teeth: gear.teeth,
      // У большой шестерёнки отверстия нет: на его месте ступица со знаком.
      holeRatio: gear.isBig ? 0 : 0.36,
    );
    // Радиальный градиент симметричен, поэтому при вращении «свет» не ездит.
    canvas.drawPath(
      path,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFE6C878), brass, copper],
          stops: [0, 0.6, 1],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: r)),
    );
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.015
      ..color = leatherDeep;
    canvas.drawPath(path, edge);
    canvas.drawCircle(Offset.zero, r * 0.58, edge);

    // Состаривание только внутри этой шестерёнки; вращается вместе с ней.
    final random = math.Random(7 + index);
    canvas.save();
    canvas.clipPath(path);
    for (var i = 0; i < 5; i++) {
      final angle = random.nextDouble() * 2 * math.pi;
      final dist = r * (0.35 + 0.6 * random.nextDouble());
      drawSoftSpot(
        canvas,
        Offset(math.cos(angle), math.sin(angle)) * dist,
        r * (0.16 + 0.16 * random.nextDouble()),
        oxide.withValues(alpha: 0.3 + 0.25 * random.nextDouble()),
      );
    }
    for (var i = 0; i < 6; i++) {
      final angle = random.nextDouble() * 2 * math.pi;
      final dist = r * (0.3 + 0.65 * random.nextDouble());
      drawScratch(
        canvas,
        Offset(math.cos(angle), math.sin(angle)) * dist,
        r * (0.1 + 0.15 * random.nextDouble()),
        random.nextDouble() * math.pi,
        const Color(0xFFFFF2C8).withValues(alpha: 0.4),
        width: 0.9,
      );
    }
    canvas.restore();

    if (!gear.isBig) {
      drawBolt(canvas, Offset.zero, r * 0.27, body: copper);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    if (s <= 0) {
      return;
    }
    final omega = 2 * math.pi / GearEmblem.revolutionSeconds;
    final t = seconds.value;

    for (var i = 0; i < _emblemGears.length; i++) {
      final gear = _emblemGears[i];
      final picture = _cache.of(i, size, (c) => _recordGear(c, gear, i, s));
      canvas.save();
      canvas.translate(gear.center.dx * s, gear.center.dy * s);
      canvas.rotate(gear.phase + gear.ratio * omega * t);
      canvas.drawPicture(picture);
      canvas.restore();
    }

    // Ступица со знаком 42 не вращается.
    final center = emblemBigCenter * s;
    final hub = emblemBigRadius * s * 0.66;
    canvas.drawCircle(center, hub, Paint()..color = emeraldDeep);
    canvas.drawCircle(
      center,
      hub,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = emblemBigRadius * s * 0.06
        ..color = brass,
    );
    drawLogo42(
      canvas,
      center,
      hub * 1.42,
      Paint()..color = const Color(0xFFE6C878),
    );
  }

  @override
  bool shouldRepaint(_EmblemPainter oldDelegate) =>
      oldDelegate.seconds != seconds;
}

/// Большая шестерня, выглядывающая из угла экрана. Ставится так, чтобы
/// **центр лежал в углу**: тогда видна четверть (см. `SteampunkBackdrop`).
/// Крутится очень медленно. Полупрозрачная, чтобы не спорить с содержимым.
class CornerGear extends StatelessWidget {
  const CornerGear({super.key, required this.radius, this.animate = true});

  /// Внешний радиус (по вершинам зубьев).
  final double radius;
  final bool animate;

  /// Секунд на один оборот.
  static const double revolutionSeconds = 160;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: GearClock(
            enabled: animate,
            builder: (context, seconds) =>
                CustomPaint(painter: _CornerGearPainter(seconds: seconds)),
          ),
        ),
      ),
    );
  }
}

class _CornerGearPainter extends CustomPainter {
  _CornerGearPainter({required this.seconds}) : super(repaint: seconds);

  final ValueListenable<double> seconds;
  final _PictureCache _cache = _PictureCache();

  static const int _teeth = 24;
  static const int _spokes = 6;
  static const double _alpha = 0.55;

  void _record(Canvas canvas, double r) {
    final tip = r * 0.97;
    final body = gearPath(
      center: Offset.zero,
      radius: tip,
      teeth: _teeth,
      holeRatio: 0.60,
    );
    canvas.drawPath(
      body,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFE6C878).withValues(alpha: _alpha),
            brass.withValues(alpha: _alpha),
            copper.withValues(alpha: _alpha),
          ],
          stops: const [0.55, 0.8, 1],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: tip)),
    );

    final hubRadius = r * 0.2;
    final ringInner = tip * 0.60;

    // Спицы: тёмная окантовка и латунная полоса поверх.
    for (var i = 0; i < _spokes; i++) {
      final angle = i * 2 * math.pi / _spokes;
      final dir = Offset(math.cos(angle), math.sin(angle));
      final from = dir * hubRadius;
      final to = dir * (ringInner + 2);
      canvas.drawLine(
        from,
        to,
        Paint()
          ..strokeWidth = r * 0.085
          ..color = leatherDeep.withValues(alpha: 0.6),
      );
      canvas.drawLine(
        from,
        to,
        Paint()
          ..strokeWidth = r * 0.06
          ..color = brass.withValues(alpha: _alpha),
      );
    }

    // Ступица и болт.
    canvas.drawCircle(
      Offset.zero,
      hubRadius,
      Paint()..color = copper.withValues(alpha: 0.65),
    );
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, r * 0.012)
      ..color = leatherDeep.withValues(alpha: 0.75);
    canvas.drawCircle(Offset.zero, hubRadius, edge);
    canvas.drawCircle(Offset.zero, r * 0.07, Paint()..color = leatherDeep.withValues(alpha: 0.6));

    // Отверстия под болты по кругу обода.
    for (var i = 0; i < 12; i++) {
      final angle = (i + 0.5) * 2 * math.pi / 12;
      canvas.drawCircle(
        Offset(math.cos(angle), math.sin(angle)) * (tip * 0.70),
        r * 0.022,
        Paint()..color = leatherDeep.withValues(alpha: 0.55),
      );
    }

    canvas.drawPath(body, edge);

    // Окись и царапины только по ободу.
    final random = math.Random(11);
    canvas.save();
    canvas.clipPath(body);
    for (var i = 0; i < 9; i++) {
      final angle = random.nextDouble() * 2 * math.pi;
      final dist = tip * (0.62 + 0.36 * random.nextDouble());
      drawSoftSpot(
        canvas,
        Offset(math.cos(angle), math.sin(angle)) * dist,
        r * (0.07 + 0.08 * random.nextDouble()),
        oxide.withValues(alpha: 0.25 + 0.25 * random.nextDouble()),
      );
    }
    for (var i = 0; i < 10; i++) {
      final angle = random.nextDouble() * 2 * math.pi;
      final dist = tip * (0.62 + 0.34 * random.nextDouble());
      drawScratch(
        canvas,
        Offset(math.cos(angle), math.sin(angle)) * dist,
        r * (0.04 + 0.06 * random.nextDouble()),
        random.nextDouble() * math.pi,
        const Color(0xFFFFF2C8).withValues(alpha: 0.35),
        width: 1,
      );
    }
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    if (r <= 0) {
      return;
    }
    final picture = _cache.of(0, size, (c) => _record(c, r));
    canvas.save();
    canvas.translate(r, r);
    canvas.rotate(2 * math.pi * seconds.value / CornerGear.revolutionSeconds);
    canvas.drawPicture(picture);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CornerGearPainter oldDelegate) =>
      oldDelegate.seconds != seconds;
}
