import 'dart:math' as math;

import 'package:flutter/material.dart';

// Мелкие приёмы «состаривания»: клёпки, болты, пятна окиси, царапины.
// Все функции только рисуют на готовом холсте и ничего не хранят.

const Color _shadow = Color(0x99000000);
const Color _rim = Color(0x66000000);
const Color _shine = Color(0x77FFFFFF);
const Color _slot = Color(0xCC1A110B);

/// Клёпка: тень, шляпка цвета [body], тёмный ободок и блик.
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

/// Болт со шлицем: клёпка и косая прорезь.
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

/// Мягкое пятно (окись): круг с размытым краем. Прозрачность задаёт [color].
void drawBlotch(Canvas canvas, Offset center, double radius, Color color) {
  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..color = color
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.45),
  );
}

/// Царапина: тонкая светлая линия длиной [length] под углом [angle].
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
