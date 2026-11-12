import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

// Small "aging" tricks: rivets, bolts, oxide stains, scratches.
// All the functions only draw on a ready canvas and store nothing.

const Color _shadow = Color(0x99000000);
const Color _rim = Color(0x66000000);
const Color _shine = Color(0x77FFFFFF);
const Color _slot = Color(0xCC1A110B);

/// A rivet: a shadow, a head of color [body], a dark rim and a highlight.
void drawRivet(
  Canvas canvas,
  Offset center,
  double radius, {
  required Color body,
}) {
  canvas.drawCircle(
    center.translate(radius * 0.25, radius * 0.35),
    radius + 0.8,
    Paint()..color = _shadow,
  );
  canvas.drawCircle(center, radius, Paint()..color = body);
  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = _rim,
  );
  canvas.drawCircle(
    center.translate(-radius * 0.3, -radius * 0.3),
    radius * 0.32,
    Paint()..color = _shine,
  );
}

/// A slotted bolt: a rivet and a slanted slot.
void drawBolt(
  Canvas canvas,
  Offset center,
  double radius, {
  required Color body,
}) {
  drawRivet(canvas, center, radius, body: body);
  final half = Offset(math.cos(0.6), math.sin(0.6)) * (radius * 0.65);
  canvas.drawLine(
    center - half,
    center + half,
    Paint()
      ..color = _slot
      ..strokeWidth = math.max(1, radius * 0.18)
      ..strokeCap = StrokeCap.round,
  );
}

/// A soft stain (oxide): a circle with a blurred edge. The opacity is set by
/// [color].
void drawBlotch(Canvas canvas, Offset center, double radius, Color color) {
  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..color = color
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.45),
  );
}

/// A soft stain **without blur**: a radial gradient from [color] to
/// transparent. It looks like [drawBlotch] but does not use `MaskFilter.blur`,
/// so it is cheap and suits rotating parts that are repainted on every frame.
void drawSoftSpot(Canvas canvas, Offset center, double radius, Color color) {
  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..shader = RadialGradient(
        colors: [color, color.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: center, radius: radius)),
  );
}

/// A scratch: a thin light line of length [length] at angle [angle].
void drawScratch(
  Canvas canvas,
  Offset start,
  double length,
  double angle,
  Color color, {
  double width = 0.8,
}) {
  final end = start + Offset(math.cos(angle), math.sin(angle)) * length;
  canvas.drawLine(
    start,
    end,
    Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round,
  );
}
