import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../data/welcome_demo.dart';
import '../l10n/l10n.dart';
import '../models/avatar.dart';
import '../motion.dart';
import '../theme.dart';
import '../widgets/brand_wordmark.dart';
import '../widgets/companion_view.dart';
import '../widgets/english_content.dart';
import '../widgets/launch_splash.dart';
import '../widgets/pressable_button.dart';

/// Welcome (V02): the wordmark, "See your mistakes clearly.", a line about
/// the app, a "Watch" card where a lens finds a mistake and the correction
/// appears, and the trio (Panda, Fox, Frog) waving at the bottom; "Get
/// started" (light haptic).
///
/// Motion: the texts enter one after another; the lens sweeps the wrong
/// sentence and the corrected one appears (a 4.2 s loop); the heroes float
/// and wave in turn, 0.3 s apart (a 3.2 s loop). Reduce Motion: the final
/// state, still.
///
/// On a first install this screen is built under the cold-start launch
/// splash: every entrance waits (drawn at its first frame) until the
/// splash's fade has finished, so none of it plays unseen.
class WelcomeScreen extends StatefulWidget {
  final VoidCallback onGetStarted;

  const WelcomeScreen({super.key, required this.onGetStarted});

  static const getStartedKey = ValueKey('welcome_get_started');

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  static const _entranceDuration = Duration(milliseconds: 1400);

  late final AnimationController _entrance =
      AnimationController(vsync: this, duration: _entranceDuration);
  AnimationController? _demo;
  AnimationController? _trio;
  bool _held = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final held = LaunchSplashScope.coveringOf(context);
    final wasHeld = _held;
    _held = held;
    if (!_initialized) {
      _initialized = true;
      if (AppMotion.reduced(context)) {
        _entrance.value = 1;
      } else if (!held) {
        _entrance.forward();
      }
    } else if (wasHeld && !held && !_entrance.isAnimating) {
      _entrance.forward();
    }
    final loops = AppMotion.loopsOn(context) && !held;
    if (loops && _demo == null) {
      _demo = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 4200))
        ..repeat();
      _trio = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 3200))
        ..repeat();
    } else if (!loops && _demo != null) {
      _demo!.dispose();
      _trio!.dispose();
      _demo = null;
      _trio = null;
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    _demo?.dispose();
    _trio?.dispose();
    super.dispose();
  }

  /// An entrance slice: [delay] ms in, [length] ms long, out of the whole.
  Animation<double> _slice(int delay, int length) => CurvedAnimation(
        parent: _entrance,
        curve: Interval(
          delay / _entranceDuration.inMilliseconds,
          math.min(1, (delay + length) / _entranceDuration.inMilliseconds),
          curve: AppMotion.enter,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final side = width < 360 ? 16.0 : 20.0;
    return Scaffold(
      backgroundColor: c.page,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(side, 20, side, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Rise(
                      progress: _slice(450, 600),
                      child: BrandWordmark(
                        maxLines: 1,
                        style: theme.textTheme.headlineSmall!
                            .withWeight(FontWeight.w900)
                            .copyWith(
                                color: c.text, fontSize: 24, letterSpacing: -1),
                      ),
                    ),
                    const SizedBox(height: 26),
                    _Rise(
                      progress: _slice(600, 650),
                      child: Text(
                        l10n.welcomeTitle,
                        style: theme.textTheme.displaySmall!
                            .withWeight(FontWeight.w900)
                            .copyWith(
                                color: c.text,
                                fontSize: 38,
                                height: 1.08,
                                letterSpacing: -1.2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _Rise(
                      progress: _slice(700, 650),
                      child: Text(
                        l10n.welcomeSubtitle,
                        style: theme.textTheme.bodyLarge!
                            .copyWith(color: c.muted, height: 1.4),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _Rise(
                      progress: _slice(800, 600),
                      child: _WatchCard(loop: _demo),
                    ),
                    const SizedBox(height: 16),
                    _Rise(
                      progress: _slice(900, 500),
                      child: _Trio(loop: _trio),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(side, 8, side, 12),
              child: FadeTransition(
                opacity: _slice(1000, 400),
                child: PressableButton(
                  key: WelcomeScreen.getStartedKey,
                  label: l10n.welcomeGetStarted,
                  tone: ButtonTone.navy,
                  shine: true,
                  haptic: ButtonHaptic.light,
                  trailingIcon: Directionality.of(context) == TextDirection.rtl
                      ? Icons.arrow_back_rounded
                      : Icons.arrow_forward_rounded,
                  onPressed: widget.onGetStarted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rises 12 px and fades in with [progress].
class _Rise extends StatelessWidget {
  final Animation<double> progress;
  final Widget child;
  const _Rise({required this.progress, required this.child});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: progress,
        builder: (context, child) => Opacity(
          opacity: progress.value,
          child: Transform.translate(
              offset: Offset(0, 12 * (1 - progress.value)), child: child),
        ),
        child: child,
      );
}

/// "Watch": the lens sweeps "She don't like coffee.", the wrong word is
/// struck, and "She doesn't like coffee." appears with its rule.
class _WatchCard extends StatelessWidget {
  final Animation<double>? loop;
  const _WatchCard({required this.loop});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final theme = Theme.of(context);
    final sentence = theme.textTheme.titleLarge!
        .withWeight(FontWeight.w900)
        .copyWith(color: c.text, fontSize: 21, letterSpacing: -.3);
    Widget content(double t) {
      // gl-lens: the lens crosses the first line (0–55 %); the strike and
      // the reveal follow (gl-strike / gl-reveal: 30–50 %).
      final lensX = t < .1 ? 0.0 : (t < .55 ? (t - .1) / .45 : 1.0);
      final reveal = t < .3 ? 0.0 : (t < .5 ? (t - .3) / .2 : 1.0);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.welcomeWatch,
              style: theme.textTheme.labelMedium!
                  .withWeight(FontWeight.w900)
                  .copyWith(color: c.navy, letterSpacing: 1.4)),
          const SizedBox(height: 12),
          EnglishContent(
            child: LayoutBuilder(builder: (context, box) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Text.rich(
                    TextSpan(children: [
                      const TextSpan(text: WelcomeDemo.wrongBefore),
                      TextSpan(
                        text: WelcomeDemo.wrongWord,
                        style: TextStyle(
                          decoration: reveal > 0
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          decorationColor: c.red,
                          decorationThickness: 2.5,
                          color: Color.lerp(c.text, c.red, reveal),
                        ),
                      ),
                      const TextSpan(text: WelcomeDemo.wrongAfter),
                    ]),
                    style: sentence,
                  ),
                  Positioned(
                    left: -10 + (box.maxWidth - 40) * lensX,
                    top: -10,
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: t < .62 ? 1 : math.max(0, 1 - (t - .62) * 5),
                        child: Image.asset('assets/ui/lens.webp',
                            width: 44, height: 44, excludeFromSemantics: true),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 14),
          Opacity(
            opacity: reveal,
            child: Transform.translate(
              offset: Offset(0, 6 * (1 - reveal)),
              child: EnglishContent(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(children: [
                        const TextSpan(text: WelcomeDemo.rightBefore),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              color: c.greenSoft,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(WelcomeDemo.rightWord,
                                style: sentence.copyWith(color: c.greenDeep)),
                          ),
                        ),
                        const TextSpan(text: WelcomeDemo.rightAfter),
                      ]),
                      style: sentence,
                    ),
                    const SizedBox(height: 6),
                    Text(WelcomeDemo.rule,
                        style: theme.textTheme.bodySmall!
                            .withWeight(FontWeight.w700)
                            .copyWith(color: c.muted)),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    final l = loop;
    return Semantics(
      label: '${WelcomeDemo.wrong} ${WelcomeDemo.right} ${WelcomeDemo.rule}',
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        decoration: lipCard(c, radius: 24),
        child: l == null
            ? content(1)
            : AnimatedBuilder(
                animation: l, builder: (context, _) => content(l.value)),
      ),
    );
  }
}

/// Panda, Fox and Frog in their wave poses (V02): the side ones float
/// (`gl-float`, 8 px, 3.2 s, 0.3 s apart) over a shadow that follows them;
/// Fox in the middle waves (`gl-wave`, CompanionView's own loop).
class _Trio extends StatelessWidget {
  final Animation<double>? loop;
  const _Trio({required this.loop});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    Widget hero(Avatar a, double size, int i, double t) {
      final waving = i == 1;
      final phase = ((t - i * .3 / 3.2) % 1.0);
      final lift = waving ? 0.0 : (1 - math.cos(2 * math.pi * phase)) / 2;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.translate(
            offset: Offset(0, -8 * lift),
            child: CompanionView(
                hero: a,
                mood: CompanionMood.wave,
                size: size,
                ambient: waving ? CompanionAmbient.mood : CompanionAmbient.none,
                decorative: true),
          ),
          Container(
            width: size * .6,
            height: 8,
            decoration: BoxDecoration(
              color: c.lip.withValues(alpha: .6 - .25 * lift),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
      );
    }

    Widget row(double t) => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            hero(Avatar.panda, 78, 0, t),
            const SizedBox(width: 8),
            hero(Avatar.fox, 112, 1, t),
            const SizedBox(width: 8),
            hero(Avatar.frog, 78, 2, t),
          ],
        );
    final l = loop;
    return ExcludeSemantics(
      child: l == null
          ? row(0)
          : AnimatedBuilder(
              animation: l, builder: (context, _) => row(l.value)),
    );
  }
}
