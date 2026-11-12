import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../l10n/app_strings.dart';
import 'steampunk/gears.dart';
import 'steampunk/steampunk_theme.dart';

/// The switch for the splash screen: with `false` the app opens the search
/// screen at once (handy when debugging, when the splash gets in the way after
/// every restart).
const bool introEnabled = true;

/// The file with the splash image (declared in `pubspec.yaml`, the assets
/// section).
const String splashImageAsset = 'assets/images/splash.jpg';

/// Image proportions (width / height): 1024 x 1536 pixels (2:3). If you replace
/// the file with another one of the same proportions (for example, larger in
/// size), nothing needs to change; with different proportions, fix the number.
const double splashImageAspect = 1024 / 1536;

/// Splash background: a solid very dark warm color (not pure black). It is the
/// same `leatherDeep` as the edges of the search screen background: after the
/// splash the background does not "jump". It is also close to the edges of the
/// image itself.
const Color splashBackgroundColor = leatherDeep;

/// What share of the image height (or width) at each edge goes into
/// transparency. Through the transparency the [splashBackgroundColor]
/// background shows, i.e. the edge of the image smoothly "sinks" into almost
/// black. The larger the number, the longer the transition and the more of the
/// image edges is lost (acceptable 0.05-0.30).
const double splashFeather = 0.12;

/// The in-app splash: the **whole** image (fitted by width, on a phone in
/// portrait; by height on a wide screen) on a solid dark background. The free
/// strips at the top and bottom are filled by the background, and the edges of
/// the image smoothly dissolve into it (a transparency gradient,
/// [splashFeather]). The image fades in smoothly, holds, and fades out, after
/// which (or on a tap) it is replaced by the [next] screen.
///
/// **The splash clock starts when the image is ready** (loaded and decoded),
/// not at the moment the screen is created. Otherwise part of the fade-in time
/// would go into loading the file, and the image would "jump out" abruptly in
/// the middle of the smooth appearance. If the image is not ready within
/// [imageWait], the clock starts anyway (so the splash does not hang).
///
/// If the screen is wider than the image (tablet, landscape), dark background
/// remains on the sides and the image edges are feathered. If it is narrower
/// (an ordinary phone in portrait), the image is cropped at the sides: we look
/// at the center.
///
/// Why it is needed when there is a system splash: on Android 12+ the system
/// shows only a small icon in the center and does not allow a whole image
/// (docs/13). So our system splash is short, with the emblem, and the image is
/// shown right after it, already by Flutter's means.
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.next,
    this.duration = const Duration(milliseconds: 5000),
    this.fadeIn = const Duration(milliseconds: 700),
    this.fadeOut = const Duration(milliseconds: 600),
    this.imageWait = const Duration(milliseconds: 1500),
    this.waitForImage = true,
    this.image = const AssetImage(splashImageAsset),
  });

  /// The screen that opens after the splash.
  final Widget next;

  /// The full duration of the splash (including fade-in and fade-out) if the
  /// user does not touch the screen.
  final Duration duration;

  /// How long the image takes to fade in at the start.
  final Duration fadeIn;

  /// How long the image takes to fade out at the end.
  final Duration fadeOut;

  /// The maximum time to wait for the image to load before starting the clock.
  final Duration imageWait;

  /// `false`: do not wait for the image, start at once (needed by tests: in the
  /// test environment image decoding does not run on the "test" clock).
  final bool waitForImage;

  /// The image (tests substitute their own, without a file).
  final ImageProvider image;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  Timer? _fallback;
  bool _requested = false;
  bool _started = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      // preserve: do not speed up 20x when "remove animations" is on, otherwise
      // the splash would flash and vanish; we turn the smoothness off ourselves
      // below.
      animationBehavior: AnimationBehavior.preserve,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _finish();
        }
      });

    // Opacity curve: 0 -> 1 (fade-in), 1 (hold), 1 -> 0 (fade-out).
    // The weight of a segment = its duration in milliseconds.
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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requested) {
      return;
    }
    _requested = true;
    if (!widget.waitForImage) {
      _start();
      return;
    }
    // Safety net: if the image did not load in time, the splash starts anyway.
    _fallback = Timer(widget.imageWait, _start);
    // Warm-up: the image is loaded and decoded in advance; the clock starts
    // when it is ready. A load error is swallowed: the emblem will show instead
    // of the image, and the clock starts anyway (the Future completes on an
    // error too).
    precacheImage(widget.image, context, onError: (_, _) {}).then((_) => _start());
  }

  /// Starts the splash clock (once).
  void _start() {
    if (_started || !mounted) {
      return;
    }
    _started = true;
    _fallback?.cancel();
    _controller.forward();
  }

  @override
  void dispose() {
    _fallback?.cancel();
    // The controller must be released: otherwise it would keep calling
    // _finish() on a destroyed state (and in tests that is also a "pending
    // timer").
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
    // "Remove animations" in the system: no smooth fade-in, the image at once.
    final opacity = MediaQuery.disableAnimationsOf(context)
        ? const AlwaysStoppedAnimation<double>(1)
        : _opacity;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
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
      backgroundColor: splashBackgroundColor,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: FadeTransition(
          key: const ValueKey('splash-fade'),
          opacity: opacity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // The image is fitted whole ("contain"): by width if the screen
              // is narrower than the image (a phone in portrait), otherwise by
              // height. The edges that have free space left are feathered into
              // the background.
              LayoutBuilder(
                builder: (context, box) {
                  final fitWidth =
                      box.maxWidth / box.maxHeight <= splashImageAspect;
                  final width = fitWidth
                      ? box.maxWidth
                      : box.maxHeight * splashImageAspect;
                  final height = width / splashImageAspect;
                  return Center(
                    child: SizedBox(
                      width: width,
                      height: height,
                      child: FeatheredEdges(
                        fade: splashFeather,
                        // Strips remain at the top and bottom if the image is
                        // fitted by width, and at the sides if it is fitted by
                        // height.
                        horizontal: !fitWidth && width < box.maxWidth - 1,
                        vertical: fitWidth && height < box.maxHeight - 1,
                        child: Image(
                          image: image,
                          fit: BoxFit.cover,
                          // No file or it is broken: the emblem instead of the
                          // image.
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
    );
  }
}

/// Feathering of the edges: opacity grows smoothly from the edges to the
/// center.
///
/// This is an alpha-channel mask: `ShaderMask` with `BlendMode.dstIn`
/// multiplies the opacity of every pixel of the child by the alpha of the
/// gradient. If both axes are on, the masks are nested and their effects
/// multiply, so the corners fade more strongly than the sides.
class FeatheredEdges extends StatelessWidget {
  const FeatheredEdges({
    super.key,
    required this.child,
    this.fade = 0.22,
    this.horizontal = true,
    this.vertical = true,
  });

  final Widget child;

  /// What share of the size on each side goes into transparency (0..0.5).
  final double fade;

  /// Feather the left and right edges.
  final bool horizontal;

  /// Feather the top and bottom edges.
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
