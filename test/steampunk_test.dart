import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swifty_companion/ui/splash_screen.dart' show splashBackgroundColor;
import 'package:swifty_companion/ui/steampunk/gear_motion.dart';
import 'package:swifty_companion/ui/steampunk/gears.dart';
import 'package:swifty_companion/ui/steampunk/pipes.dart';
import 'package:swifty_companion/ui/steampunk/steampunk_theme.dart';
import 'package:swifty_companion/ui/steampunk/steampunk_widgets.dart';

import 'test_app.dart';

/// The WCAG contrast ratio: (light + 0.05) / (dark + 0.05).
double contrast(Color a, Color b) {
  final la = a.computeLuminance() + 0.05;
  final lb = b.computeLuminance() + 0.05;
  return la > lb ? la / lb : lb / la;
}

void main() {
  group('palette', () {
    // The panel background (walnut) and the screen/AppBar (dark leather). Text
    // and icons on them.
    final pairs = <(String, Color, Color, double)>[
      ('main text on the panel', steampunkColors.onSurface, steampunkColors.surface, 7),
      ('main text on the background', steampunkColors.onSurface, leatherDeep, 7),
      ('captions on the panel', steampunkColors.onSurfaceVariant, steampunkColors.surface, 4.5),
      ('brass on the panel', steampunkColors.primary, steampunkColors.surface, 4.5),
      ('brass on the background (AppBar)', steampunkColors.primary, leatherDeep, 4.5),
      ('"passed" on the panel', steampunkColors.tertiary, steampunkColors.surface, 4.5),
      ('"failed" on the panel', steampunkColors.error, steampunkColors.surface, 4.5),
      ('button text', steampunkColors.onPrimary, steampunkColors.primary, 4.5),
      ('error text', steampunkColors.onErrorContainer, steampunkColors.errorContainer, 4.5),
      ('section titles (oxide) on the panel', sectionTitleColor, steampunkColors.surface, 4.5),
      ('input field label', mutedBrass, walnutDeep, 4.5),
      ('initials on the photo placeholder (large text)', mutedBrass, walnutLight, 3),
    ];

    for (final (name, foreground, background, minimum) in pairs) {
      test('contrast: $name at least $minimum:1', () {
        expect(contrast(foreground, background), greaterThanOrEqualTo(minimum));
      });
    }

    // Iteration 9: the panel was darker than the center of the background and
    // merged with it (1.13:1). Now it is lighter than the background at ALL
    // points of the radial gradient, and stands out by tone, not by the border
    // alone.
    test('the panel is lighter than the background everywhere: in the center and at the gradient edges', () {
      for (final background in backdropColors) {
        expect(
          walnut.computeLuminance(),
          greaterThan(background.computeLuminance()),
          reason: '$background',
        );
      }
      expect(contrast(walnut, backdropColors.first), greaterThanOrEqualTo(1.25));
      expect(contrast(walnut, backdropColors.last), greaterThanOrEqualTo(1.3));
    });

    test('the photo placeholder differs from the panel, the input field is darker than the panel', () {
      expect(contrast(walnutLight, walnut), greaterThanOrEqualTo(1.2));
      expect(walnutDeep.computeLuminance(), lessThan(walnut.computeLuminance()));
    });

    test('splash and AppBar are unchanged: the shared background edge leatherDeep', () {
      expect(backdropColors.last, leatherDeep);
      expect(splashBackgroundColor, leatherDeep);
    });

    test('the theme builds and is dark', () {
      final theme = buildSteampunkTheme();
      expect(theme.colorScheme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, leatherDeep);
    });
  });

  group('gearPath', () {
    const center = Offset(100, 100);

    test('teeth within the radius, a hole in the center', () {
      final path = gearPath(center: center, radius: 50, teeth: 10);
      final bounds = path.getBounds();

      expect(bounds.left, greaterThanOrEqualTo(49.9));
      expect(bounds.right, lessThanOrEqualTo(150.1));
      expect(bounds.top, greaterThanOrEqualTo(49.9));
      expect(bounds.bottom, lessThanOrEqualTo(150.1));

      expect(path.contains(center), isFalse); // hole
      expect(path.contains(center + const Offset(25, 0)), isTrue); // body
      expect(path.contains(center + const Offset(60, 0)), isFalse); // outside
    });
  });

  group('painting', () {
    test('GearsPainter paints on a canvas without errors, including an empty one', () {
      const painter = GearsPainter(color: brass);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(400, 800));
      painter.paint(canvas, Size.zero);
      recorder.endRecording().dispose();
    });

    test('oxidized gears: changing the oxide color also repaints', () {
      const base = GearsPainter(color: brass);
      expect(base.shouldRepaint(const GearsPainter(color: brass, patina: copper)), isTrue);
    });

    test('shouldRepaint: only when the color or the seed changes', () {
      const base = GearsPainter(color: brass);
      expect(base.shouldRepaint(const GearsPainter(color: brass)), isFalse);
      expect(base.shouldRepaint(const GearsPainter(color: copper)), isTrue);
      expect(base.shouldRepaint(const GearsPainter(color: brass, seed: 1)), isTrue);
    });

    testWidgets('the background and the panel show the content and do not loop the animation',
        (tester) async {
      await tester.pumpWidget(
        testApp(
          const Scaffold(
            body: SteampunkBackdrop(
              child: Center(child: BrassPanel(child: Text('hola'))),
            ),
          ),
        ),
      );
      // If the pattern animated endlessly, pumpAndSettle would not return.
      await tester.pumpAndSettle();

      expect(find.text('hola'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the emblem and the ring are painted', (tester) async {
      await tester.pumpWidget(
        testApp(
          const Scaffold(
            body: Center(
              child: BrassRing(child: GearEmblem(size: 100)),
            ),
          ),
        ),
      );

      expect(find.byType(GearEmblem), findsOneWidget);
      // 100 (emblem) + 2 * 13 (the default ring)
      expect(tester.getSize(find.byType(BrassRing)), const Size(126, 126));
    });

    testWidgets('panels of any size paint without errors, including tiny ones',
        (tester) async {
      for (final side in [20.0, 59.0, 61.0, 120.0, 400.0]) {
        await tester.pumpWidget(
          testApp(
            Scaffold(
              body: Center(
                child: SizedBox(
                  width: side,
                  height: side,
                  child: const BrassPanel(padding: EdgeInsets.zero, child: SizedBox.expand()),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull, reason: 'side $side');
      }
    });

    testWidgets('brass line: height and insertion into the AppBar', (tester) async {
      expect(const BrassLine().preferredSize.height, BrassLine.height);

      await tester.pumpWidget(
        testApp(
          Scaffold(
            appBar: AppBar(title: const Text('t'), bottom: const BrassLine()),
          ),
        ),
      );

      expect(find.byType(BrassLine), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('PipesPainter paints pipes and cables, paints nothing on a tiny window', () {
      const painter = PipesPainter();
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(400, 800));
      painter.paint(canvas, const Size(100, 100));
      painter.paint(canvas, Size.zero);
      recorder.endRecording().dispose();
      expect(painter.shouldRepaint(const PipesPainter()), isFalse);
    });

    testWidgets('corner gear: the center in the bottom right corner, a quarter is visible',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 800);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        testApp(const Scaffold(body: SteampunkBackdrop(child: SizedBox()))),
      );

      final gear = find.byType(CornerGear);
      expect(gear, findsOneWidget);
      // The center of the gear is exactly in the corner of a 400 x 800 screen.
      expect(tester.getCenter(gear), const Offset(400, 800));
      // Radius: 46 % of the short side, but not less than 100 and not more than
      // 260.
      expect(tester.getSize(gear), const Size(2 * 184, 2 * 184));
    });
  });

  group('emblem: a chain of seven gears of four sizes', () {
    final gears = placeEmblemGears();

    test('there are seven, the big one is first and driving', () {
      expect(gears, hasLength(7));
      expect(gears.first.isBig, isTrue);
      expect(gears.first.parent, -1);
      expect(gears.skip(1).every((g) => !g.isBig), isTrue);
    });

    test('four different sizes: not "one big and four equal"', () {
      final radii = gears.map((g) => g.radius).toSet();
      expect(radii, hasLength(4));
      // The big one is clearly larger than the others, the smallest clearly
      // smaller.
      expect(gears.first.radius, greaterThan(radii.reduce(math.max) - 1e-9));
      expect(gears.first.radius / radii.reduce(math.min), greaterThan(2));
    });

    test('the chain is asymmetric: branching and depth greater than two', () {
      int depth(int i) => gears[i].parent < 0 ? 0 : 1 + depth(gears[i].parent);
      expect(List.generate(gears.length, depth).reduce(math.max), greaterThanOrEqualTo(3));

      // Branching: some gear has at least two "children"; and there is a gear
      // whose children have children of their own in the chain (not a star
      // around one).
      final children = <int, int>{};
      for (final g in gears.skip(1)) {
        children[g.parent] = (children[g.parent] ?? 0) + 1;
      }
      expect(children.values.reduce(math.max), greaterThanOrEqualTo(2));
      expect(children.keys.where((i) => i != 0), isNotEmpty);
    });

    test('all fit into the emblem square with a margin', () {
      for (final g in gears) {
        expect(g.center.dx - g.radius, greaterThanOrEqualTo(0.02));
        expect(g.center.dy - g.radius, greaterThanOrEqualTo(0.02));
        expect(g.center.dx + g.radius, lessThanOrEqualTo(0.98));
        expect(g.center.dy + g.radius, lessThanOrEqualTo(0.98));
      }
    });

    test('each is meshed with its parent: the tooth tip enters the gap but not deeper', () {
      for (final g in gears.skip(1)) {
        final p = gears[g.parent];
        final distance = (g.center - p.center).distance;
        // The tooth tip of one gear does not go deeper than the gap of the
        // other (the gap is at 0.8 of the radius) and yet they are meshed: the
        // axes are closer than the sum of the radii.
        expect(distance, greaterThanOrEqualTo(p.radius + 0.8 * g.radius - 1e-9));
        expect(distance, greaterThanOrEqualTo(g.radius + 0.8 * p.radius - 1e-9));
        expect(distance, lessThan(p.radius + g.radius));
      }
    });

    test('unmeshed gears do not touch each other', () {
      for (var i = 0; i < gears.length; i++) {
        for (var j = i + 1; j < gears.length; j++) {
          if (gears[j].parent == i || gears[i].parent == j) {
            continue; // a meshed pair
          }
          final distance = (gears[i].center - gears[j].center).distance;
          expect(distance, greaterThan(gears[i].radius + gears[j].radius + 0.02),
              reason: 'gears $i and $j');
        }
      }
    });

    test('the tooth pitch is close for all: teeth fit into the neighbors gaps', () {
      // Pitch = the arc length at the outer radius per tooth.
      final pitches = [
        for (final g in gears) 2 * math.pi * g.radius / g.teeth,
      ];
      final lowest = pitches.reduce(math.min);
      final highest = pitches.reduce(math.max);
      expect(highest / lowest, lessThan(1.15));
    });

    test('speeds are inversely proportional to the tooth count, neighbors turn against each other', () {
      expect(gears.first.ratio, 1);
      for (final g in gears.skip(1)) {
        final p = gears[g.parent];
        expect(g.ratio.sign, -p.ratio.sign);
        // The linear speed on the pitch circle is the same: ω₁·z₁ = -ω₂·z₂.
        expect(g.ratio * g.teeth, closeTo(-p.ratio * p.teeth, 1e-9));
        // For any gear the speed magnitude depends only on the tooth count.
        expect(g.ratio.abs() * g.teeth, closeTo(emblemBigTeeth.toDouble(), 1e-9));
      }
    });

    test('teeth enter the gaps at any moment of the rotation (for the whole chain)', () {
      // The meshing condition: at the contact point the parent's "tooth
      // fraction" plus the child's "tooth fraction" equals 0.5 (mod 1): a tooth
      // against a gap.
      final omega = 2 * math.pi / emblemRevolutionSeconds;
      for (final g in gears.skip(1)) {
        final p = gears[g.parent];
        final alpha = math.atan2(
          g.center.dy - p.center.dy,
          g.center.dx - p.center.dx,
        );
        for (final t in [0.0, 1.7, 9.3, 36.0, 123.456]) {
          final thetaParent = p.phase + p.ratio * omega * t;
          final thetaChild = g.phase + g.ratio * omega * t;
          final fractionParent = (alpha - thetaParent) * p.teeth / (2 * math.pi);
          final fractionChild =
              (alpha + math.pi - thetaChild) * g.teeth / (2 * math.pi);
          final sum = (fractionParent + fractionChild) % 1;
          expect(sum, closeTo(0.5, 1e-9),
              reason: 'gear with ${g.teeth} teeth, t=$t');
        }
      }
    });

    test('geometry: the outlines of meshed pairs do not intersect at any moment', () {
      // The most reliable check: we take the real outlines (gearPath) and count
      // whether a point falls inside both. A sample of grid points in the area
      // where the pair's circles intersect.
      const scale = 1000.0;
      final omega = 2 * math.pi / emblemRevolutionSeconds;
      for (final t in [0.0, 3.1, 11.0, 47.5]) {
        Path pathOf(PlacedGear g) => gearPath(
              center: g.center * scale,
              radius: g.radius * scale,
              teeth: g.teeth,
              rotation: g.phase + g.ratio * omega * t,
              holeRatio: 0,
            );
        for (final g in gears.skip(1)) {
          final a = pathOf(gears[g.parent]);
          final b = pathOf(g);
          final mid = (g.center + gears[g.parent].center) * (scale / 2);
          var bothInside = 0;
          for (var dx = -90.0; dx <= 90; dx += 3) {
            for (var dy = -90.0; dy <= 90; dy += 3) {
              final point = mid + Offset(dx, dy);
              if (a.contains(point) && b.contains(point)) {
                bothInside++;
              }
            }
          }
          expect(bothInside, 0, reason: 'teeth ran into each other, t=$t, teeth: ${g.teeth}');
        }
      }
    });
  });

  group('rotation', () {
    Widget scene({required bool disableAnimations}) => testApp(
          const Scaffold(
            body: Center(child: GearEmblem(size: 120)),
          ),
          disableAnimations: disableAnimations,
        );

    testWidgets('by default the gears rotate: frames are scheduled', (tester) async {
      await tester.pumpWidget(scene(disableAnimations: false));
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.binding.transientCallbackCount, greaterThan(0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('"remove animations" in the system: the gears stand still', (tester) async {
      await tester.pumpWidget(scene(disableAnimations: true));
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpAndSettle(); // does not hang
    });

    testWidgets('animate: false stops the rotation', (tester) async {
      await tester.pumpWidget(
        testApp(
          const Scaffold(body: Center(child: GearEmblem(animate: false))),
          disableAnimations: false,
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('the clock runs with time',
        (tester) async {
      final seen = <double>[];
      Widget clock({required bool enabled}) => testApp(
            GearClock(
              enabled: enabled,
              builder: (context, seconds) {
                seconds.addListener(() => seen.add(seconds.value));
                return const SizedBox();
              },
            ),
            disableAnimations: false,
          );

      await tester.pumpWidget(clock(enabled: true));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(seen, isNotEmpty);
      expect(seen.last, greaterThan(0.9));
    });

    testWidgets('leaving the screen releases the clock without errors', (tester) async {
      await tester.pumpWidget(scene(disableAnimations: false));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));

      expect(tester.takeException(), isNull);
      expect(tester.binding.transientCallbackCount, 0);
    });
  });
}
