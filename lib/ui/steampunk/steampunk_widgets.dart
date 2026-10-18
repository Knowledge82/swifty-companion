import 'package:flutter/material.dart';

import 'gears.dart';
import 'steampunk_theme.dart';

/// Фон экрана: тёмная кожа с лёгким светом в центре и узором шестерёнок.
/// Узор рисуется один раз и закрыт `RepaintBoundary`, поэтому прокрутка
/// содержимого его не перерисовывает.
class SteampunkBackdrop extends StatelessWidget {
  const SteampunkBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Stack(
      // expand: содержимое получает весь экран, а не «сколько ему нужно».
      fit: StackFit.expand,
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.3),
                radius: 1.2,
                colors: [leather, leatherDeep],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: ExcludeSemantics(
            child: RepaintBoundary(
              child: CustomPaint(painter: GearsPainter(color: primary)),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Латунная панель: кожаный фон, латунная рамка и заклёпки по углам.
/// Фон чуть прозрачный, чтобы шестерёнки позади угадывались.
class BrassPanel extends StatelessWidget {
  const BrassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.primary, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color(0x99000000), blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: CustomPaint(
        foregroundPainter: _RivetPainter(color: colors.primary),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class _RivetPainter extends CustomPainter {
  const _RivetPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 8.0;
    final head = Paint()..color = color;
    final dent = Paint()..color = leatherDeep.withValues(alpha: 0.6);
    for (final p in [
      const Offset(inset, inset),
      Offset(size.width - inset, inset),
      Offset(inset, size.height - inset),
      Offset(size.width - inset, size.height - inset),
    ]) {
      canvas.drawCircle(p, 3, head);
      canvas.drawCircle(p.translate(0.8, 0.8), 1.2, dent);
    }
  }

  @override
  bool shouldRepaint(_RivetPainter oldDelegate) => oldDelegate.color != color;
}

/// Латунное кольцо вокруг круглого фото: градиент латуни в медь, тень.
/// Полный размер = размер фото + 2 × [thickness].
class BrassRing extends StatelessWidget {
  const BrassRing({super.key, required this.child, this.thickness = 6});

  final Widget child;
  final double thickness;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE6C878), brass, copper],
        ),
        boxShadow: [
          BoxShadow(color: Color(0x99000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Padding(padding: EdgeInsets.all(thickness), child: child),
    );
  }
}
