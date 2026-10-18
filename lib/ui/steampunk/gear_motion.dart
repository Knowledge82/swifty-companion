import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Строитель, которому отдают «часы» вращения: число секунд с момента старта.
typedef GearClockBuilder = Widget Function(
  BuildContext context,
  ValueListenable<double> seconds,
);

/// Часы для вращающихся шестерёнок.
///
/// Внутри обычный `Ticker`: он вызывается на каждом кадре и обновляет число
/// секунд. Рисующий код (`CustomPainter(repaint: seconds)`) подписан на это
/// число и перерисовывается **сам**, без пересборки дерева виджетов: это
/// дёшево.
///
/// Часы **не идут** (и шестерёнки стоят), если:
/// - `enabled == false`;
/// - в системе включено «убрать анимации» (`MediaQuery.disableAnimations`):
///   это настройка доступности для людей, которых движение тошнит или
///   отвлекает, и уважать её правильно;
/// - экран закрыт другим экраном или приложение свёрнуто: `Ticker`
///   автоматически замолкает через `TickerMode`, батарея не тратится.
///
/// В тестах `testApp` включает `disableAnimations`, поэтому `pumpAndSettle`
/// не зависает на вечной анимации (иначе кадры никогда бы не кончились).
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
