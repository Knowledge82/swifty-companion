import 'package:flutter/material.dart';

/// Знак школы 42 в виде четырёх многоугольников.
///
/// Координаты взяты из файла `tool/42_logo.svg` (его принёс владелец проекта;
/// знак использовать можно: в проекте ft_hangouts он обязателен). Они
/// переписаны сюда как есть, без правок, чтобы не тащить в приложение пакет
/// для SVG. Тест `logo42_test.dart` сверяет эти числа с файлом, так что
/// расхождение не пройдёт незамеченным.
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

/// Габариты знака в координатах файла: ширина 896, высота 629.1.
const Rect logo42Bounds = Rect.fromLTRB(32, -51.1, 928, 578);

/// Рисует знак так, чтобы центр его габаритов оказался в [center],
/// а ширина стала [width]. Пропорции сохраняются.
void drawLogo42(Canvas canvas, Offset center, double width, Paint paint) {
  final scale = width / logo42Bounds.width;
  final shift = center - logo42Bounds.center * scale;
  for (final polygon in logo42Polygons) {
    final path = Path()
      ..addPolygon([for (final p in polygon) p * scale + shift], true);
    canvas.drawPath(path, paint);
  }
}
