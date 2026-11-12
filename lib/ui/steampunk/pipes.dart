import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'steampunk_theme.dart';
import 'wear.dart';

/// Pipes and cables along the screen edges, on the very back layer.
///
/// - **Corrugated pipes** run along the left edge (two, with bends) and come
///   out from behind the screen edge. The corrugation is drawn as frequent
///   transverse strokes along the pipe outline: a dark groove and a light
///   highlight next to it. Flanges with bolts sit at the joints.
/// - **Cables** hang on the right: a dark braid, a colored core and a plug at
///   the end. Three colors (oxidized copper, rust, brass).
///
/// Everything is static, drawn once and wrapped in a `RepaintBoundary` in
/// `SteampunkBackdrop`. The whole layer is semi-transparent (via `saveLayer`),
/// so as not to compete with the content. Positions are given as fractions of
/// the screen size.
class PipesPainter extends CustomPainter {
  const PipesPainter();

  static const double _layerOpacity = 0.62;
  static const Color _pipeBody = Color(0xFF8A5A2B);
  static const Color _sheen = Color(0x55FFF2C8);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // On a really small window (for example, split screen) the pipes would only
    // get in the way.
    if (w < 200 || h < 300) {
      return;
    }

    canvas.saveLayer(
      Offset.zero & size,
      Paint()..color = Colors.white.withValues(alpha: _layerOpacity),
    );

    // The upper pipe: from behind the left edge, down along the edge, back
    // behind the edge.
    final y0 = h * 0.14;
    final y1 = h * 0.50;
    final upper = Path()
      ..moveTo(-14, y0)
      ..lineTo(8, y0)
      ..quadraticBezierTo(17, y0, 17, y0 + 10)
      ..lineTo(17, y1)
      ..quadraticBezierTo(17, y1 + 10, 8, y1 + 10)
      ..lineTo(-14, y1 + 10);
    _corrugated(canvas, upper, 12);
    _flange(canvas, upper, 20, 12);
    _flange(canvas, upper, upper.computeMetrics().first.length - 20, 12);

    // The lower pipe: down along the edge and right along the bottom edge.
    final y2 = h * 0.70;
    final bottomY = h - 20;
    final lower = Path()
      ..moveTo(-14, y2)
      ..lineTo(8, y2)
      ..quadraticBezierTo(17, y2, 17, y2 + 10)
      ..lineTo(17, bottomY - 10)
      ..quadraticBezierTo(17, bottomY, 27, bottomY)
      ..lineTo(w * 0.40, bottomY);
    _corrugated(canvas, lower, 12);
    _flange(canvas, lower, 20, 12);
    _flange(canvas, lower, lower.computeMetrics().first.length - 24, 12);

    // Cables on the right: they hang from the top and end with plugs.
    _cable(
      canvas,
      Path()
        ..moveTo(w + 6, h * 0.10)
        ..cubicTo(w - 30, h * 0.14, w - 6, h * 0.30, w - 14, h * 0.44),
      verdigris,
    );
    _cable(
      canvas,
      Path()
        ..moveTo(w + 6, h * 0.13)
        ..cubicTo(w - 22, h * 0.20, w - 2, h * 0.40, w - 10, h * 0.62),
      rust,
    );
    _cable(
      canvas,
      Path()
        ..moveTo(w + 6, h * 0.18)
        ..cubicTo(w - 34, h * 0.30, w - 4, h * 0.50, w - 16, h * 0.76),
      brass,
    );

    canvas.restore();
  }

  Paint _stroke(double width, Color color) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeJoin = StrokeJoin.round
    ..color = color;

  /// A corrugated pipe of width [width] along the outline [path].
  void _corrugated(Canvas canvas, Path path, double width) {
    canvas.drawPath(path, _stroke(width + 3, leatherDeep.withValues(alpha: 0.85)));
    canvas.drawPath(path, _stroke(width, _pipeBody));
    canvas.drawPath(path, _stroke(width * 0.28, _sheen));

    final groove = _stroke(1.6, leatherDeep.withValues(alpha: 0.6));
    final light = _stroke(0.9, const Color(0x44FFF2C8));
    for (final metric in path.computeMetrics()) {
      for (var d = 2.0; d < metric.length; d += 6) {
        final tangent = metric.getTangentForOffset(d);
        if (tangent == null) {
          continue;
        }
        final dir = tangent.vector / math.max(tangent.vector.distance, 1e-9);
        final normal = Offset(-dir.dy, dir.dx) * (width / 2);
        final p = tangent.position;
        canvas.drawLine(p - normal, p + normal, groove);
        final shifted = dir * 2.4;
        canvas.drawLine(p - normal + shifted, p + normal + shifted, light);
      }
    }
  }

  /// A flange (a ring with bolts) at distance [distance] from the start of the
  /// pipe.
  void _flange(Canvas canvas, Path path, double distance, double pipeWidth) {
    final metric = path.computeMetrics().first;
    final tangent = metric.getTangentForOffset(
      distance.clamp(0, metric.length).toDouble(),
    );
    if (tangent == null) {
      return;
    }
    canvas.save();
    canvas.translate(tangent.position.dx, tangent.position.dy);
    canvas.rotate(tangent.angle);
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: 6, height: pipeWidth + 7),
      const Radius.circular(1.5),
    );
    canvas.drawRRect(rect, Paint()..color = brass);
    canvas.drawRRect(rect, _stroke(1, leatherDeep.withValues(alpha: 0.8)));
    final bolt = pipeWidth / 2 + 1.2;
    drawRivet(canvas, Offset(0, -bolt), 1.9, body: const Color(0xFFE9CE86));
    drawRivet(canvas, Offset(0, bolt), 1.9, body: const Color(0xFFE9CE86));
    canvas.restore();
  }

  /// A cable: a dark braid, a colored core, two clamps and a plug at the end.
  void _cable(Canvas canvas, Path path, Color core) {
    canvas.drawPath(path, _stroke(5.2, leatherDeep.withValues(alpha: 0.9)));
    canvas.drawPath(path, _stroke(3.2, core.withValues(alpha: 0.85)));
    canvas.drawPath(path, _stroke(1, const Color(0x66FFF2C8)));

    final metric = path.computeMetrics().first;
    for (final fraction in [0.3, 0.62]) {
      final t = metric.getTangentForOffset(metric.length * fraction);
      if (t == null) {
        continue;
      }
      canvas.save();
      canvas.translate(t.position.dx, t.position.dy);
      canvas.rotate(t.angle);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: 3.5, height: 8),
          const Radius.circular(1),
        ),
        Paint()..color = copper,
      );
      canvas.restore();
    }

    // The plug at the end: a brass body and two pins.
    final end = metric.getTangentForOffset(metric.length);
    if (end == null) {
      return;
    }
    canvas.save();
    canvas.translate(end.position.dx, end.position.dy);
    canvas.rotate(end.angle);
    final plug = RRect.fromRectAndRadius(
      Rect.fromLTRB(-3, -5, 10, 5),
      const Radius.circular(2),
    );
    canvas.drawRRect(plug, Paint()..color = brass);
    canvas.drawRRect(plug, _stroke(1, leatherDeep.withValues(alpha: 0.85)));
    final pin = _stroke(1.4, const Color(0xFFE9CE86));
    canvas.drawLine(const Offset(10, -2.2), const Offset(14, -2.2), pin);
    canvas.drawLine(const Offset(10, 2.2), const Offset(14, 2.2), pin);
    canvas.restore();
  }

  @override
  bool shouldRepaint(PipesPainter oldDelegate) => false;
}
