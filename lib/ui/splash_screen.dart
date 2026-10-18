import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import 'steampunk/gears.dart';
import 'steampunk/steampunk_theme.dart';
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

/// Заставка внутри приложения: на весь экран картинка с размытыми краями,
/// через [duration] (или по касанию) плавно сменяется экраном [next].
///
/// Зачем она нужна, если есть системный splash: на Android 12+ система
/// показывает только маленький значок по центру, а целую картинку не
/// разрешает (docs/13). Поэтому системный splash у нас короткий, с эмблемой,
/// а картинка показывается сразу следом, уже средствами Flutter.
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.next,
    this.duration = const Duration(milliseconds: 2400),
    this.image = const AssetImage(splashImageAsset),
  });

  /// Экран, который открывается после заставки.
  final Widget next;

  /// Сколько показывать заставку, если пользователь не коснулся экрана.
  final Duration duration;

  /// Картинка (в тестах подставляется своя, без файла).
  final ImageProvider image;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration, _finish);
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
    // Без этого таймер сработал бы после ухода экрана и вызвал setState
    // у уничтоженного состояния (а в тестах это ещё и «висящий таймер»).
    _timer?.cancel();
    super.dispose();
  }

  void _finish() {
    _timer?.cancel();
    if (!mounted || _done) {
      return;
    }
    setState(() => _done = true);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      child: _done
          ? KeyedSubtree(key: const ValueKey('next'), child: widget.next)
          : _Intro(
              key: const ValueKey('intro'),
              image: widget.image,
              onTap: _finish,
            ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({super.key, required this.image, required this.onTap});

  final ImageProvider image;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: leatherDeep,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SteampunkBackdrop(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Картинка вписана в экран целиком (как BoxFit.contain),
              // а по краям растушёвана: там, где экран шире или выше
              // картинки, она плавно переходит в фон с шестерёнками.
              Center(
                child: AspectRatio(
                  aspectRatio: splashImageAspect,
                  child: FeatheredEdges(
                    child: Image(
                      image: image,
                      fit: BoxFit.cover,
                      // Нет файла или он битый: эмблема вместо картинки.
                      errorBuilder: (_, _, _) => const Center(child: GearEmblem()),
                    ),
                  ),
                ),
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
    );
  }
}

/// Растушёвка краёв: прозрачность плавно растёт от краёв к центру.
///
/// Это маска по альфа-каналу: `ShaderMask` с режимом `BlendMode.dstIn`
/// умножает прозрачность каждого пикселя ребёнка на альфу градиента.
/// Две маски вложены друг в друга (по вертикали и по горизонтали), и их
/// действия перемножаются, поэтому углы затухают сильнее сторон.
class FeatheredEdges extends StatelessWidget {
  const FeatheredEdges({super.key, required this.child, this.fade = 0.22});

  final Widget child;

  /// Какая доля размера с каждой стороны уходит в прозрачность (0..0.5).
  final double fade;

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
    return _mask(
      Alignment.centerLeft,
      Alignment.centerRight,
      _mask(Alignment.topCenter, Alignment.bottomCenter, child),
    );
  }
}
