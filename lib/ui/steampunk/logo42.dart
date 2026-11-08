import 'package:flutter/material.dart';

/// The school's 42 mark as four polygons.
///
/// The coordinates are taken from the file `tool/42_logo.svg` (brought by the
/// project owner; the mark may be used: it is mandatory in the ft_hangouts
/// project). They are copied here as they are, without changes, so as not to
/// pull an SVG package into the app. The test `logo42_test.dart` checks these
/// numbers against the file, so a mismatch will not go unnoticed.
const List<List<Offset>> logo42Polygons = [
  [
    Offset(32, 412.6),
    Offset(362.1, 412.6),
    Offset(362.1, 578),
    Offset(526.8, 578),
    Offset(526.8, 279.1),
    Offset(197.3, 279.1),
    Offset(526.8, -51.1),
    Offset(362.1, -51.1),
    Offset(32, 279.1),
  ],
  [
    Offset(597.9, 114.2),
    Offset(762.7, -51.1),
    Offset(597.9, -51.1),
  ],
  [
    Offset(762.7, 114.2),
    Offset(597.9, 279.1),
    Offset(597.9, 443.9),
    Offset(762.7, 443.9),
    Offset(762.7, 279.1),
    Offset(928, 114.2),
    Offset(928, -51.1),
    Offset(762.7, -51.1),
  ],
  [
    Offset(928, 279.1),
    Offset(762.7, 443.9),
    Offset(928, 443.9),
  ],
];

/// Dimensions of the mark in the file's coordinates: width 896, height 629.1.
const Rect logo42Bounds = Rect.fromLTRB(32, -51.1, 928, 578);

/// Draws the mark so that the center of its bounds ends up at [center] and its
/// width becomes [width]. Proportions are preserved.
void drawLogo42(Canvas canvas, Offset center, double width, Paint paint) {
  final scale = width / logo42Bounds.width;
  final shift = center - logo42Bounds.center * scale;
  for (final polygon in logo42Polygons) {
    final path = Path()
      ..addPolygon([for (final p in polygon) p * scale + shift], true);
    canvas.drawPath(path, paint);
  }
}
