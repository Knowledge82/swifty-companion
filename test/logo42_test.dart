import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swifty_companion/ui/steampunk/logo42.dart';

/// Reads the polygons from the SVG file: the attributes `points="x,y x,y ..."`.
List<List<Offset>> polygonsFromSvg(String svg) {
  final number = RegExp(r'-?\d+(?:\.\d+)?');
  return [
    for (final match in RegExp(r'points="([^"]*)"').allMatches(svg))
      () {
        final values = number
            .allMatches(match.group(1)!)
            .map((m) => double.parse(m.group(0)!))
            .toList();
        return [
          for (var i = 0; i + 1 < values.length; i += 2)
            Offset(values[i], values[i + 1]),
        ];
      }(),
  ];
}

void main() {
  test('the numbers in Dart match the file tool/42_logo.svg', () {
    final fromFile = polygonsFromSvg(File('tool/42_logo.svg').readAsStringSync());

    expect(fromFile, hasLength(4));
    expect(logo42Polygons, equals(fromFile));
  });

  test('the mark bounds are computed correctly', () {
    final all = logo42Polygons.expand((p) => p);
    final minX = all.map((p) => p.dx).reduce((a, b) => a < b ? a : b);
    final maxX = all.map((p) => p.dx).reduce((a, b) => a > b ? a : b);
    final minY = all.map((p) => p.dy).reduce((a, b) => a < b ? a : b);
    final maxY = all.map((p) => p.dy).reduce((a, b) => a > b ? a : b);

    expect(logo42Bounds, Rect.fromLTRB(minX, minY, maxX, maxY));
  });

  test('draws without errors at any width', () {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    for (final width in [0.0, 1.0, 100.0, 5000.0]) {
      drawLogo42(canvas, const Offset(50, 50), width, Paint());
    }
    recorder.endRecording().dispose();
  });
}
