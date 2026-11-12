import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'gear_motion.dart';
import 'logo42.dart';
import 'steampunk_theme.dart';
import 'wear.dart';

/// The outline of a gear: [teeth] teeth around [center], a hole in the middle.
///
/// Each tooth is a trapezoid: two points at the "root" (radius 0.8 of the outer
/// one) and two at the tip. The hole is added to the same outline with the
/// `evenOdd` rule, so when filled a hole is left in the center.
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

/// A pattern of semi-transparent gears over the whole area.
///
/// The layout is deterministic (a fixed `seed`): the canvas is divided into
/// cells of 150 pixels, and in each (except randomly skipped ones) a gear of
/// random size, with a random number of teeth and rotation is drawn.
/// About every third gear is oxidized: it is drawn in the [patina] color
/// (green), the rest are brass ([color]).
/// The pattern is static: without animation it costs the CPU nothing and does
/// not interfere with `pumpAndSettle` in tests.
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
        // Random numbers are spent in the same order for every cell, so that
        // skipping one cell does not shift the pattern in all the following
        // ones.
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

/// A cache of drawn pictures: each is drawn once for a given size and then only
/// replayed (with rotation). The gear outline, the stains and the scratches are
/// not recomputed on every frame.
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

/// One gear of the emblem with its position and phase already computed.
@visibleForTesting
class PlacedGear {
  const PlacedGear({
    required this.center,
    required this.radius,
    required this.teeth,
    required this.phase,
    required this.ratio,
    this.parent = -1,
  });

  /// Center and radius as fractions of the emblem side (0..1).
  final Offset center;
  final double radius;
  final int teeth;

  /// The initial rotation at which the teeth enter the gaps of the neighbor.
  final double phase;

  /// How many times faster and in which direction it turns relative to the big
  /// one. The big one has 1; each next one in the chain turns **against** its
  /// "parent" (the sign alternates), and the speed is inversely proportional to
  /// the number of teeth (see [placeEmblemGears]).
  final double ratio;

  /// Index of the gear this one meshes with (in the layout list);
  /// -1 for the big, driving one.
  final int parent;

  bool get isBig => parent < 0;
}

/// The big gear of the emblem (as a fraction of the side) and its tooth count.
@visibleForTesting
const double emblemBigRadius = 0.26;
@visibleForTesting
const int emblemBigTeeth = 13;
@visibleForTesting
const Offset emblemBigCenter = Offset(0.347, 0.585);

/// Seconds per one revolution of the emblem's big gear.
@visibleForTesting
const double emblemRevolutionSeconds = 36;

/// A layout of seven gears of **four sizes** (0.26, 0.19, 0.14, 0.10 of the
/// emblem side) assembled into an asymmetric chain: the big one at the bottom
/// left drives the middle one on the right, that one drives two smaller ones,
/// and then the chain goes up and to the left to the smallest.
///
/// The layout is not "fitted by eye" but computed:
/// - the **distance between axes** is such that the tip of a tooth of one
///   almost touches the gap of the other: `max(R + 0.8·r, r + 0.8·R) + gap`
///   (our gap is at 0.8 of the radius, see [gearPath]);
/// - the **phase**: so that at the contact point a tooth of one falls into a
///   gap of the other, the sum of the "tooth fractions" on both sides must be
///   0.5. The initial rotation of the meshed gear follows from this condition.
///   The "parent" now has a non-zero phase (it is itself meshed with its own
///   parent), so its phase enters the formula too;
/// - the **speed**: for meshed gears the speed is inversely proportional to the
///   tooth count and directed the opposite way. For a chain this means `ratio =
///   -parent_ratio · parent_teeth / teeth`. Then the phase condition holds at
///   any moment, and the teeth do not run into each other.
///
/// The tooth counts are chosen so that the tooth pitch (the arc length per
/// tooth) is close for all of them (0.12-0.13): the teeth of one gear must fit
/// into the gaps of the other, and with a different pitch they would catch.
///
/// The layout itself (angles and sizes) was found by a script: a random search
/// with the checks "everything inside the square with a margin", "unmeshed
/// gears do not touch (a gap of at least 0.02)" and a raster check that meshed
/// pairs do not intersect at any moment of the rotation. The tests below repeat
/// these checks.
@visibleForTesting
List<PlacedGear> placeEmblemGears() {
  const children = <(int, double, double, int)>[
    // (parent index, angle from the parent in degrees, radius, teeth)
    (0, -15.6, 0.19, 9),
    (1, 88.9, 0.14, 7),
    (1, -78.9, 0.14, 7),
    (3, 179.8, 0.14, 7),
    (4, -170.6, 0.10, 5),
    (0, 123.6, 0.10, 5),
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
  for (final (parentIndex, degrees, radius, teeth) in children) {
    final parent = result[parentIndex];
    final alpha = degrees * math.pi / 180;
    final distance =
        math.max(parent.radius + 0.8 * radius, radius + 0.8 * parent.radius) + 0.01;
    final center = parent.center + Offset(math.cos(alpha), math.sin(alpha)) * distance;
    // The fraction of the parent's teeth in the direction of the neighbor
    // (taking its phase into account).
    final toothFractionParent =
        (alpha - parent.phase) * parent.teeth / (2 * math.pi);
    final phase =
        alpha + math.pi - (0.5 - toothFractionParent) * 2 * math.pi / teeth;
    result.add(
      PlacedGear(
        center: center,
        radius: radius,
        teeth: teeth,
        phase: phase,
        ratio: -parent.ratio * parent.teeth / teeth,
        parent: parentIndex,
      ),
    );
  }
  return result;
}

final List<PlacedGear> _emblemGears = placeEmblemGears();

/// The emblem: seven meshed brass gears of four sizes (a chain without
/// symmetry) with oxide and scratches, **rotating** (if animations are not
/// disabled, see [GearClock]).
/// On the big gear there is a dark hub with the school's 42 mark (it does not
/// rotate: the mark is always readable), on the small ones there are bolts.
/// Purely decorative.
class GearEmblem extends StatelessWidget {
  const GearEmblem({super.key, this.size = 120, this.animate = true});

  final double size;

  /// `false`: the gears stand still (for example, in a screenshot or a test).
  final bool animate;

  /// Seconds per revolution of the big gear. The others turn in the ratio of
  /// the tooth counts (the smallest ones, with 5 teeth, 2.6 times faster).
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

  /// Draws the gear itself in its own coordinates (center at zero, no
  /// rotation): afterwards this picture is only rotated.
  void _recordGear(Canvas canvas, PlacedGear gear, int index, double s) {
    final r = gear.radius * s;
    final path = gearPath(
      center: Offset.zero,
      radius: r,
      teeth: gear.teeth,
      // The big gear has no hole: in its place is a hub with the mark.
      holeRatio: gear.isBig ? 0 : 0.36,
    );
    // The radial gradient is symmetric, so the "light" does not travel when
    // rotating.
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

    // Aging only inside this gear; it rotates together with it.
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

    // The hub with the 42 mark does not rotate.
    final center = emblemBigCenter * s;
    final hub = emblemBigRadius * s * 0.66;
    canvas.drawCircle(center, hub, Paint()..color = walnutDeep);
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

/// A big gear peeking out from a corner of the screen. It is placed so that the
/// **center lies in the corner**: then a quarter is visible (see
/// `SteampunkBackdrop`). Turns very slowly. Semi-transparent, so as not to
/// compete with the content.
class CornerGear extends StatelessWidget {
  const CornerGear({super.key, required this.radius, this.animate = true});

  /// Outer radius (to the tooth tips).
  final double radius;
  final bool animate;

  /// Seconds per revolution.
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

    // Spokes: a dark outline and a brass strip on top.
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

    // Hub and bolt.
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

    // Bolt holes around the circle of the rim.
    for (var i = 0; i < 12; i++) {
      final angle = (i + 0.5) * 2 * math.pi / 12;
      canvas.drawCircle(
        Offset(math.cos(angle), math.sin(angle)) * (tip * 0.70),
        r * 0.022,
        Paint()..color = leatherDeep.withValues(alpha: 0.55),
      );
    }

    canvas.drawPath(body, edge);

    // Oxide and scratches only on the rim.
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
