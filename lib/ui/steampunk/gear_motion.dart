import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// A builder that is given the rotation "clock": the number of seconds since
/// the start.
typedef GearClockBuilder = Widget Function(
  BuildContext context,
  ValueListenable<double> seconds,
);

/// A clock for rotating gears.
///
/// Inside is an ordinary `Ticker`: it is called on every frame and updates the
/// number of seconds. The painting code (`CustomPainter(repaint: seconds)`) is
/// subscribed to this number and repaints **by itself**, without rebuilding the
/// widget tree: this is cheap.
///
/// The clock **does not run** (and the gears stand still) if:
/// - `enabled == false`;
/// - the system has "remove animations" on (`MediaQuery.disableAnimations`):
///   this is an accessibility setting for people who get nauseous or distracted
///   by motion, and respecting it is the right thing;
/// - the screen is covered by another screen or the app is minimized: the
///   `Ticker` goes silent automatically through `TickerMode`, no battery is
///   wasted.
///
/// In tests `testApp` turns on `disableAnimations`, so `pumpAndSettle` does not
/// hang on an endless animation (otherwise the frames would never end).
class GearClock extends StatefulWidget {
  const GearClock({super.key, required this.builder, this.enabled = true});

  final GearClockBuilder builder;
  final bool enabled;

  @override
  State<GearClock> createState() => _GearClockState();
}

class _GearClockState extends State<GearClock>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<double> _seconds = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker(_onTick);

  void _onTick(Duration elapsed) {
    _seconds.value = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(GearClock oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final run = widget.enabled && !MediaQuery.disableAnimationsOf(context);
    if (run && !_ticker.isActive) {
      _ticker.start();
    } else if (!run && _ticker.isActive) {
      _ticker.stop();
      _seconds.value = 0;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _seconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _seconds);
}
