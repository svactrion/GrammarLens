import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../l10n/l10n.dart';
import '../models/avatar.dart';
import '../motion.dart';
import '../theme.dart';
import 'companion_view.dart';
import 'thinking_dots.dart';

/// V04's three states (SPEC V04, v11; storyboard V04s).
enum NameStage {
  /// The field is empty: wave, "Hi! What should I call you?".
  asks,

  /// Typing: inspect (looking at the field through its lens), three dots.
  listens,

  /// 700 ms after the last key with a valid name: cheer, one hop, three
  /// sparkles, "Nice to meet you, <name>!".
  greets,
}

/// V04 (v11): the companion large and centred (142 pt) in a warm glow over
/// a white disc, its speech bubble above it with the tail pointing down at
/// it. The bubble pops on each change; the glow breathes (3.2 s); the
/// greeting's companion hops once among three sparkles. On first build the
/// companion rises 12 pt with a fade (300 ms) and the bubble pops (350 ms).
/// Reduce Motion: no hop, no glow loop, no rise or pop.
class NameCompanionStage extends StatefulWidget {
  final Avatar hero;
  final NameStage stage;

  /// The name being greeted (trimmed); only [NameStage.greets] shows it.
  final String name;

  const NameCompanionStage({
    super.key,
    required this.hero,
    required this.stage,
    required this.name,
  });

  static const double companionSize = 142;
  static const double glowSize = 240;
  static const double discSize = 140;

  /// From the bubble's tail tip down to the companion's box (the board's
  /// 147 → 160).
  static const double bubbleGap = 13;
  static const double maxBubbleWidth = 330;

  /// The board's glow and disc sit 7 pt below the companion's centre.
  static const double glowDrop = 7;

  /// The name in the bubble is cut after this many characters, then "…"
  /// (the field keeps it whole).
  static const int nameLimit = 16;

  static const bubbleKey = ValueKey('name_stage_bubble');
  static const glowKey = ValueKey('name_stage_glow');
  static ValueKey<String> sparkleKey(int i) =>
      ValueKey('name_stage_sparkle_$i');

  /// The three sparkles round the greeting companion, from the board:
  /// (left, top) from the companion's top left, size, period, delay.
  static const sparkles = <(Offset, double, int, int)>[
    (Offset(-16, 12), 26, 1800, 0),
    (Offset(138, 36), 22, 2100, 400),
    (Offset(126, -10), 16, 1600, 900),
  ];

  static CompanionMood moodFor(NameStage stage) => switch (stage) {
        NameStage.asks => CompanionMood.wave,
        NameStage.listens => CompanionMood.inspect,
        NameStage.greets => CompanionMood.cheer,
      };

  /// [name] as the bubble shows it: at most [nameLimit] characters, then
  /// "…".
  static String shortName(String name) {
    final chars = name.characters;
    return chars.length > nameLimit ? '${chars.take(nameLimit)}…' : name;
  }

  @override
  State<NameCompanionStage> createState() => _NameCompanionStageState();
}

const _sparkleClock = 100800;

class _NameCompanionStageState extends State<NameCompanionStage>
    with TickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 350));
  AnimationController? _glow;
  AnimationController? _sparkle;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final loops = AppMotion.loopsOn(context);
    if (loops && _glow == null) {
      _glow = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 3200))
        ..repeat();
      // One clock for the three sparkles (1.8, 2.1 and 1.6 s): each reads
      // its phase from their least common multiple, 100.8 s.
      _sparkle = AnimationController(
          vsync: this, duration: const Duration(milliseconds: _sparkleClock))
        ..repeat();
    } else if (!loops && _glow != null) {
      _glow!.dispose();
      _sparkle!.dispose();
      _glow = _sparkle = null;
    }
    if (!_enter.isAnimating && _enter.value == 0) {
      if (AppMotion.reduced(context)) {
        _enter.value = 1;
      } else {
        _enter.forward();
      }
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    _glow?.dispose();
    _sparkle?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    const size = NameCompanionStage.companionSize;
    const half = size / 2;
    final greets = widget.stage == NameStage.greets;
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      final companionLeft = w / 2 - half;
      // Anchored to the stage's bottom: the companion's box is its last
      // [size] points.
      const glowCentreUp = half - NameCompanionStage.glowDrop;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            key: NameCompanionStage.glowKey,
            left: w / 2 - NameCompanionStage.glowSize / 2,
            bottom: glowCentreUp - NameCompanionStage.glowSize / 2,
            width: NameCompanionStage.glowSize,
            height: NameCompanionStage.glowSize,
            child: _Glow(color: c.orangeSoft, loop: _glow),
          ),
          Positioned(
            left: w / 2 - NameCompanionStage.discSize / 2,
            bottom: glowCentreUp - NameCompanionStage.discSize / 2,
            width: NameCompanionStage.discSize,
            height: NameCompanionStage.discSize,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.card.withValues(alpha: .6),
              ),
            ),
          ),
          // The board's soft ground shadow under the companion.
          Positioned(
            left: companionLeft + size * .22,
            width: size * .56,
            bottom: size * .01,
            height: size * .08,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF462D14).withValues(alpha: .22),
                  borderRadius: const BorderRadius.all(
                      Radius.elliptical(size * .28, size * .04)),
                ),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                      maxWidth: math.min(NameCompanionStage.maxBubbleWidth, w)),
                  child: _Bubble(stage: widget.stage, name: widget.name),
                ),
              ),
              const SizedBox(height: NameCompanionStage.bubbleGap),
              Center(
                child: AnimatedBuilder(
                  animation: _enter,
                  builder: (context, child) {
                    final t = Curves.easeOut
                        .transform((_enter.value * 350 / 300).clamp(0.0, 1.0));
                    return Opacity(
                      opacity: t,
                      child: Transform.translate(
                          offset: Offset(0, 12 * (1 - t)), child: child),
                    );
                  },
                  child: CompanionView(
                    hero: widget.hero,
                    mood: NameCompanionStage.moodFor(widget.stage),
                    size: size,
                    // The board's three sparkles take the cheer prop's
                    // place; wave and inspect have none.
                    showProp: false,
                    // One hop on the greeting, then still (the sparkles
                    // and the glow keep moving).
                    cheerHops: 1,
                    ambient:
                        greets ? CompanionAmbient.none : CompanionAmbient.mood,
                    decorative: true,
                  ),
                ),
              ),
            ],
          ),
          if (greets)
            for (var i = 0; i < NameCompanionStage.sparkles.length; i++)
              Positioned(
                key: NameCompanionStage.sparkleKey(i),
                left: companionLeft + NameCompanionStage.sparkles[i].$1.dx,
                bottom: size -
                    NameCompanionStage.sparkles[i].$1.dy -
                    NameCompanionStage.sparkles[i].$2,
                width: NameCompanionStage.sparkles[i].$2,
                height: NameCompanionStage.sparkles[i].$2,
                child: _Sparkle(
                  loop: _sparkle,
                  periodMs: NameCompanionStage.sparkles[i].$3,
                  delayMs: NameCompanionStage.sparkles[i].$4,
                ),
              ),
        ],
      );
    });
  }
}

/// The warm radial glow (the board's `gl-glow11`: scale 1 ↔ 1.06, opacity
/// .75 ↔ 1, 3.2 s); still at full with the loops off.
class _Glow extends StatelessWidget {
  final Color color;
  final Animation<double>? loop;
  const _Glow({required this.color, required this.loop});

  @override
  Widget build(BuildContext context) {
    final glow = DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // The board's `radial-gradient(circle, …0 %, …45 %, …70 %)`
        // measures to the far corner (170 pt): 45 % and 70 % of it are 64 %
        // and 99 % of this 120 pt radius.
        gradient: RadialGradient(colors: [
          color,
          color.withValues(alpha: .55),
          color.withValues(alpha: 0),
        ], stops: const [
          0,
          .64,
          1
        ]),
      ),
    );
    final l = loop;
    if (l == null) return ExcludeSemantics(child: glow);
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: l,
        builder: (context, child) {
          final w = (1 - math.cos(2 * math.pi * l.value)) / 2;
          return Opacity(
            opacity: .75 + .25 * w,
            child: Transform.scale(scale: 1 + .06 * w, child: child),
          );
        },
        child: glow,
      ),
    );
  }
}

/// One sparkle (the board's `gl-sparkle`: 0 → 1.1 → 0.9 → 0 with a turn);
/// shown whole with the loops off.
class _Sparkle extends StatelessWidget {
  final Animation<double>? loop;
  final int periodMs;
  final int delayMs;
  const _Sparkle(
      {required this.loop, required this.periodMs, required this.delayMs});

  @override
  Widget build(BuildContext context) {
    const image = Image(
      image: AssetImage('assets/companions/props/prop_sparkle.webp'),
      fit: BoxFit.contain,
      excludeFromSemantics: true,
    );
    final l = loop;
    if (l == null) return image;
    return AnimatedBuilder(
      animation: l,
      builder: (context, child) {
        final ms = l.value * _sparkleClock - delayMs;
        final p = ms < 0 ? 0.0 : (ms % periodMs) / periodMs;
        // 0 % and 100 %: gone; 30 %: 1.1, turned 20°; 60 %: 0.9, 40°;
        // 80 %: faded.
        double scale, turn, opacity;
        if (p < .3) {
          scale = 1.1 * p / .3;
          turn = 20 * p / .3;
          opacity = p / .3;
        } else if (p < .6) {
          scale = 1.1 - .2 * (p - .3) / .3;
          turn = 20 + 20 * (p - .3) / .3;
          opacity = 1;
        } else if (p < .8) {
          scale = .9 - .9 * (p - .6) / .4;
          turn = 40;
          opacity = 1 - (p - .6) / .2;
        } else {
          scale = 0;
          turn = 40;
          opacity = 0;
        }
        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.rotate(
            angle: turn * math.pi / 180,
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
      child: image,
    );
  }
}

/// The bubble above the companion: 18 pt black text (the greeting's name
/// in orange), or three navy dots while listening; the tail points down at
/// the companion. Pops (0.6 → 1.06 → 1, 350 ms) on each change.
class _Bubble extends StatelessWidget {
  final NameStage stage;
  final String name;
  const _Bubble({required this.stage, required this.name});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final style = Theme.of(context)
        .textTheme
        .titleMedium!
        .withWeight(FontWeight.w900)
        .copyWith(color: c.text, fontSize: 18, height: 1.3);
    final String label;
    final Widget content;
    switch (stage) {
      case NameStage.asks:
        label = l10n.onboardingNameAsk;
        content = Text(label, textAlign: TextAlign.center, style: style);
      case NameStage.listens:
        label = '';
        // One line of text's height, so the bubble keeps its size.
        content = SizedBox(
          height: MediaQuery.textScalerOf(context).scale(18 * 1.3),
          child: Align(
            widthFactor: 1,
            child: ThinkingDots(color: c.navy, size: 9),
          ),
        );
      case NameStage.greets:
        // The sentence around the name, from the translation (the name's
        // place differs by language).
        const mark = '\u{E000}';
        final shown = NameCompanionStage.shortName(name);
        final parts = l10n.onboardingNiceToMeet(mark).split(mark);
        label = l10n.onboardingNiceToMeet(shown);
        content = Text.rich(
          TextSpan(children: [
            TextSpan(text: parts.first),
            TextSpan(text: shown, style: TextStyle(color: c.orangeDeep)),
            if (parts.length > 1) TextSpan(text: parts.sublist(1).join(mark)),
          ]),
          textAlign: TextAlign.center,
          style: style,
        );
    }
    final bubble = Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: lipCard(c, radius: 22, lipHeight: 4),
          child: content,
        ),
        Positioned(bottom: -8, child: _Tail(c: c)),
      ],
    );
    final reduced = AppMotion.reduced(context);
    return Semantics(
      liveRegion: label.isNotEmpty,
      label: label.isEmpty ? null : label,
      child: ExcludeSemantics(
        child: TweenAnimationBuilder<double>(
          // A new state pops; so does a new greeting, not each key while
          // listening.
          key:
              ValueKey(stage == NameStage.greets ? 'greets|$name' : stage.name),
          tween: Tween(begin: reduced ? 1 : 0, end: 1),
          duration: const Duration(milliseconds: 350),
          builder: (context, t, child) {
            // gl-pop11: 0.6 → 1.06 at 70 % → 1, fading in by 70 %.
            final scale =
                t < .7 ? .6 + .46 * (t / .7) : 1.06 - .06 * ((t - .7) / .3);
            return Opacity(
              opacity: (t / .7).clamp(0.0, 1.0),
              child: Transform.scale(
                scale: scale,
                alignment: Alignment.bottomCenter,
                child: child,
              ),
            );
          },
          child: KeyedSubtree(key: NameCompanionStage.bubbleKey, child: bubble),
        ),
      ),
    );
  }
}

/// The bubble's tail: a 16 pt square turned 45°, bordered on its two
/// outer sides.
class _Tail extends StatelessWidget {
  final AppColors c;
  const _Tail({required this.c});

  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: math.pi / 4,
        child: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: c.card,
            border: Border(
              right: BorderSide(color: c.line, width: 2),
              bottom: BorderSide(color: c.line, width: 2),
            ),
          ),
        ),
      );
}
