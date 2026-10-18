import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import 'steampunk/gears.dart';
import 'steampunk/steampunk_widgets.dart';

/// Выключатель экрана-заставки: `false` и приложение сразу открывает поиск
/// (удобно при отладке, когда заставка мешает после каждого перезапуска).
const bool introEnabled = true;

/// Файл с картинкой заставки (объявлен в `pubspec.yaml`, раздел assets).
const String splashImageAsset = 'assets/images/splash.jpg';

/// Пропорции картинки (ширина / высота): 564 × 845 пикселей.
/// Если заменишь файл на другой с теми же пропорциями (например, больше
/// по размеру), менять ничего не надо; с другими пропорциями поправь число.
const double splashImageAspect = 564 / 845;

/// Цвета фона заставки: тёмный серо-зелёный, **не чисто чёрный**.
/// В центре чуть светлее, по краям темнее.
const List<Color> splashBackdropColors = [Color(0xFF3A4A40), Color(0xFF1E2B25)];

/// Заставка внутри приложения: картинка вписана **по высоте экрана**,
/// плавно проявляется (fade-in), держится и плавно гаснет (fade-out), после
/// чего (или по касанию) сменяется экраном [next].
///
/// Если экран шире картинки (планшет, ландшафт), по бокам остаётся тёмный
/// фон, а края картинки растушёваны. Если уже (обычный телефон в портрете),
/// картинка обрезается по бокам: смотрим на центр.
///
/// Зачем она нужна, если есть системный splash: на Android 12+ система
/// показывает только маленький значок по центру, а целую картинку не
/// разрешает (docs/13). Поэтому системный splash у нас короткий, с эмблемой,
/// а картинка показывается сразу следом, уже средствами Flutter.
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.next,
    this.duration = const Duration(milliseconds: 3400),
    this.fadeIn = const Duration(milliseconds: 800),
    this.fadeOut = const Duration(milliseconds: 700),
    this.image = const AssetImage(splashImageAsset),
  });

  /// Экран, который открывается после заставки.
  final Widget next;

  /// Полная длительность заставки (вместе с появлением и угасанием),
  /// если пользователь не коснулся экрана.
  final Duration duration;

  /// Сколько картинка проявляется в начале.
  final Duration fadeIn;

  /// Сколько картинка гаснет в конце.
  final Duration fadeOut;

  /// Картинка (в тестах подставляется своя, без файла).
  final ImageProvider image;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      // preserve: не ускорять 20-кратно при включённом «убрать анимации»,
      // иначе заставка мелькнёт и пропадёт; плавность мы отключаем сами ниже.
      animationBehavior: AnimationBehavior.preserve,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _finish();
        }
      });

    // Кривая прозрачности: 0 → 1 (появление), 1 (держим), 1 → 0 (угасание).
    // Вес участка = его длительность в миллисекундах.
    int ms(Duration d) => d.inMilliseconds < 1 ? 1 : d.inMilliseconds;
    final hold = widget.duration - widget.fadeIn - widget.fadeOut;
    _opacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOut)),
        weight: ms(widget.fadeIn).toDouble(),
      ),
      if (hold > Duration.zero)
        TweenSequenceItem(
          tween: ConstantTween<double>(1),
          weight: ms(hold).toDouble(),
        ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: ms(widget.fadeOut).toDouble(),
      ),
    ]).animate(_controller);

    _controller.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Прогрев: картинка декодируется заранее, чтобы не «выскакивала» с задержкой.
    // Ошибку загрузки глотаем: вместо картинки покажется эмблема.
    precacheImage(widget.image, context, onError: (_, _) {});
  }

  @override
  void dispose() {
    // Контроллер надо освободить: иначе он продолжил бы звать _finish()
    // у уничтоженного состояния (а в тестах это ещё и «висящий таймер»).
    _controller.dispose();
    super.dispose();
  }

  void _finish() {
    if (!mounted || _done) {
      return;
    }
    setState(() => _done = true);
  }

  @override
  Widget build(BuildContext context) {
    // «Убрать анимации» в системе: без плавного появления, картинка сразу.
    final opacity = MediaQuery.disableAnimationsOf(context)
        ? const AlwaysStoppedAnimation<double>(1)
        : _opacity;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      child: _done
          ? KeyedSubtree(key: const ValueKey('next'), child: widget.next)
          : _Intro(
              key: const ValueKey('intro'),
              image: widget.image,
              opacity: opacity,
              onTap: _finish,
            ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({
    super.key,
    required this.image,
    required this.opacity,
    required this.onTap,
  });

  final ImageProvider image;
  final Animation<double> opacity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: splashBackdropColors.last,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SteampunkBackdrop(
          colors: splashBackdropColors,
          child: FadeTransition(
            key: const ValueKey('splash-fade'),
            opacity: opacity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Картинка вписана по высоте экрана. OverflowBox даёт ей
                // «нужную» ширину (высота × пропорции) независимо от ширины
                // экрана, а ClipRect обрезает то, что вылезло за экран.
                LayoutBuilder(
                  builder: (context, box) {
                    final height = box.maxHeight;
                    final width = height * splashImageAspect;
                    return ClipRect(
                      child: OverflowBox(
                        minWidth: width,
                        maxWidth: width,
                        minHeight: height,
                        maxHeight: height,
                        child: FeatheredEdges(
                          // Растушёвка нужна, только если по бокам виден фон.
                          horizontal: width < box.maxWidth,
                          vertical: false,
                          child: Image(
                            image: image,
                            fit: BoxFit.cover,
                            // Нет файла или он битый: эмблема вместо картинки.
                            errorBuilder: (_, _, _) =>
                                const Center(child: GearEmblem()),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                SafeArea(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 32),
                      child: Semantics(
                        header: true,
                        child: Text(
                          AppStrings.of(context).appTitle,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                            shadows: const [
                              Shadow(color: Colors.black, blurRadius: 10),
                              Shadow(color: Colors.black, blurRadius: 3),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Растушёвка краёв: прозрачность плавно растёт от краёв к центру.
///
/// Это маска по альфа-каналу: `ShaderMask` с режимом `BlendMode.dstIn`
/// умножает прозрачность каждого пикселя ребёнка на альфу градиента.
/// Если включены обе оси, маски вложены друг в друга, и их действия
/// перемножаются, поэтому углы затухают сильнее сторон.
class FeatheredEdges extends StatelessWidget {
  const FeatheredEdges({
    super.key,
    required this.child,
    this.fade = 0.22,
    this.horizontal = true,
    this.vertical = true,
  });

  final Widget child;

  /// Какая доля размера с каждой стороны уходит в прозрачность (0..0.5).
  final double fade;

  /// Растушёвать левый и правый края.
  final bool horizontal;

  /// Растушёвать верхний и нижний края.
  final bool vertical;

  Widget _mask(Alignment begin, Alignment end, Widget child) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => LinearGradient(
        begin: begin,
        end: end,
        colors: const [
          Color(0x00FFFFFF),
          Color(0xFFFFFFFF),
          Color(0xFFFFFFFF),
          Color(0x00FFFFFF),
        ],
        stops: [0, fade, 1 - fade, 1],
      ).createShader(rect),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    var result = child;
    if (vertical) {
      result = _mask(Alignment.topCenter, Alignment.bottomCenter, result);
    }
    if (horizontal) {
      result = _mask(Alignment.centerLeft, Alignment.centerRight, result);
    }
    return result;
  }
}
