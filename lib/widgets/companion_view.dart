import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/avatar.dart';
import '../motion.dart';

/// A companion's state (SPEC §3.5). Screens pass a mood; [CompanionView]
/// picks the image, the motion and the prop.
enum CompanionMood { idle, wave, cheer, think, inspect, sad, sleep, oops }

extension on CompanionMood {
  /// The pose image's name, or null for the base avatar (`idle`, `oops`).
  String? get pose => switch (this) {
        CompanionMood.idle || CompanionMood.oops => null,
        _ => name,
      };

  /// The ambient loop's period.
  Duration get period => switch (this) {
        CompanionMood.idle => const Duration(milliseconds: 3000),
        CompanionMood.wave => const Duration(milliseconds: 2400),
        CompanionMood.cheer => const Duration(milliseconds: 3000),
        CompanionMood.think => const Duration(milliseconds: 2400),
        CompanionMood.inspect => const Duration(milliseconds: 3200),
        CompanionMood.sad => const Duration(milliseconds: 2600),
        CompanionMood.sleep => const Duration(milliseconds: 3000),
        CompanionMood.oops => const Duration(milliseconds: 1800),
      };
}

/// The one companion widget (V00-CompanionSystem, X01, X03): the hero in a
/// mood, at [size] × [size]. Props sit at the top right of the head and may
/// draw outside the square.
///
/// Motion per mood (SPEC §3.5): idle breathes (scale 1 ↔ 1.04, 3 s); wave
/// bobs; cheer hops twice (−14 px, 300 ms easeOut) then breathes, with
/// sparkles 0 → 1.1 → 0; think tilts −6° (2.4 s); inspect tilts slowly; sad
/// droops (±3°, 4 px down, 2.6 s; saturation 0.55); sleep breathes in Y
/// (1 ↔ 1.03, 3 s; brightness 0.82); oops shakes its head ±8° twice in
/// 360 ms while a sweat drop falls. Under Reduce Motion (and while loops are
/// off) only the still pose and its prop show; the one-shot hops and shake
/// are skipped.
///
/// [replay] restarts the one-shot motion (a new hop) when it changes.
class CompanionView extends StatefulWidget {
  final Avatar hero;
  final CompanionMood mood;
  final double size;
  final bool showProp;
  final Object? replay;

  /// Read by VoiceOver; defaults to "<Hero>, your companion".
  final String? semanticLabel;

  /// Excludes the image from semantics (decorative repeats).
  final bool decorative;

  /// Replaces the mood's ambient loop with a hop loop (`gl-hop`, 1.2 s):
  /// the Daily Test card waiting for its test (X05, V15).
  final bool hopping;

  const CompanionView({
    super.key,
    required this.hero,
    this.mood = CompanionMood.idle,
    this.size = 120,
    this.showProp = true,
    this.replay,
    this.semanticLabel,
    this.decorative = false,
    this.hopping = false,
  });

  /// The image a mood shows for [hero].
  static String assetFor(Avatar hero, CompanionMood mood) {
    final pose = mood.pose;
    return pose == null ? hero.assetPath : hero.posePath(pose);
  }

  /// The prop a mood shows, or null.
  static String? propFor(CompanionMood mood) => switch (mood) {
        CompanionMood.cheer => 'assets/companions/props/prop_sparkle.webp',
        CompanionMood.think => 'assets/companions/props/prop_thought.webp',
        CompanionMood.sad => 'assets/companions/props/prop_cloud.webp',
        CompanionMood.sleep => 'assets/companions/props/prop_zzz.webp',
        CompanionMood.oops => 'assets/companions/props/prop_sweat.webp',
        _ => null,
      };

  @override
  State<CompanionView> createState() => _CompanionViewState();
}

class _CompanionViewState extends State<CompanionView>
    with TickerProviderStateMixin {
  AnimationController? _loop;
  late final AnimationController _once = AnimationController(
    vsync: this,
    duration: _onceDuration(widget.mood),
  );
  bool _initialized = false;

  static Duration _onceDuration(CompanionMood mood) => switch (mood) {
        CompanionMood.cheer => const Duration(milliseconds: 600),
        CompanionMood.oops => const Duration(milliseconds: 720),
        _ => Duration.zero,
      };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncLoop();
    if (!_initialized) {
      _initialized = true;
      _playOnce();
    }
  }

  @override
  void didUpdateWidget(CompanionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mood != widget.mood) {
      _loop?.dispose();
      _loop = null;
      _syncLoop();
    }
    if (oldWidget.mood != widget.mood || oldWidget.replay != widget.replay) {
      _playOnce();
    }
  }

  void _syncLoop() {
    final on = AppMotion.loopsOn(context);
    if (on && _loop == null) {
      _loop = AnimationController(
          vsync: this,
          duration: widget.hopping
              ? const Duration(milliseconds: 1200)
              : widget.mood.period)
        ..repeat();
    } else if (!on && _loop != null) {
      _loop!.dispose();
      _loop = null;
    }
  }

  void _playOnce() {
    final d = _onceDuration(widget.mood);
    if (d == Duration.zero || AppMotion.reduced(context)) {
      _once.value = 1;
      return;
    }
    _once.duration = d;
    _once.forward(from: 0);
  }

  @override
  void dispose() {
    _loop?.dispose();
    _once.dispose();
    super.dispose();
  }

  /// The body's transform for loop phase [t] (0–1) and one-shot [o] (0–1).
  Matrix4 _body(double t, double o) {
    final s = widget.size;
    // 0 → 1 → 0 over one period, smooth (the CSS `ease-in-out` 0/50/100 %).
    final wave = (1 - math.cos(2 * math.pi * t)) / 2;
    final m = Matrix4.identity();
    if (widget.hopping && _loop != null) {
      // gl-hop: up 16 px (squash and stretch) in the first 65 %, then rest.
      final p = t;
      if (p < .3) {
        final k = Curves.easeOut.transform(p / .3);
        m
          ..translateByDouble(0, -16 * k * s / 110, 0, 1)
          ..scaleByDouble(1 - .04 * k, 1 + .05 * k, 1, 1);
      } else if (p < .5) {
        final k = (p - .3) / .2;
        m
          ..translateByDouble(0, -16 * (1 - k) * s / 110, 0, 1)
          ..scaleByDouble(.96 + .1 * k, 1.05 - .13 * k, 1, 1);
      } else if (p < .65) {
        final k = (p - .5) / .15;
        m.scaleByDouble(1.06 - .06 * k, .92 + .08 * k, 1, 1);
      }
      return m;
    }
    switch (widget.mood) {
      case CompanionMood.idle:
        final k = 1 + .04 * wave;
        m.scaleByDouble(k, k, 1, 1);
      case CompanionMood.wave:
        m
          ..translateByDouble(0, -4 * wave * s / 110, 0, 1)
          ..rotateZ(_deg(-1 + 2 * wave));
      case CompanionMood.cheer:
        if (o < 1) {
          // Two hops of 300 ms, easeOut up, back down.
          final local = (o * 2) % 1.0;
          final up = math.sin(math.pi * Curves.easeOut.transform(local));
          m.translateByDouble(0, -14 * up * s / 110, 0, 1);
        } else {
          final k = 1 + .04 * wave;
          m.scaleByDouble(k, k, 1, 1);
        }
      case CompanionMood.think:
        m.rotateZ(_deg(-6 * wave));
      case CompanionMood.inspect:
        m
          ..translateByDouble(0, -2 * wave * s / 110, 0, 1)
          ..rotateZ(_deg(-2 * wave));
      case CompanionMood.sad:
        m
          ..translateByDouble(0, (2 + 2 * wave) * s / 110, 0, 1)
          ..rotateZ(_deg(-3 + 6 * wave));
      case CompanionMood.sleep:
        m.scaleByDouble(1, 1 + .03 * wave, 1, 1);
      case CompanionMood.oops:
        if (o < 1) {
          // ±8°, twice, 360 ms each.
          final local = (o * 2) % 1.0;
          m.rotateZ(_deg(8 * math.sin(2 * math.pi * local) * (1 - local)));
        }
    }
    return m;
  }

  static double _deg(double d) => d * math.pi / 180;

  /// The prop's placement in a 110 × 110 box (X01), scaled to [size].
  Rect? _propRect() {
    final k = widget.size / 110;
    return switch (widget.mood) {
      CompanionMood.cheer => Rect.fromLTWH(92 * k, -6 * k, 40 * k, 40 * k),
      CompanionMood.think => Rect.fromLTWH(84 * k, -26 * k, 64 * k, 64 * k),
      CompanionMood.sad => Rect.fromLTWH(26 * k, -34 * k, 64 * k, 64 * k),
      CompanionMood.sleep => Rect.fromLTWH(86 * k, -24 * k, 48 * k, 48 * k),
      CompanionMood.oops => Rect.fromLTWH(92 * k, 4 * k, 28 * k, 28 * k),
      _ => null,
    };
  }

  Widget _prop(double t, Rect rect, String asset) {
    final k = widget.size / 110;
    final wave = (1 - math.cos(2 * math.pi * t)) / 2;
    final moving = _loop != null;
    var dx = 0.0, dy = 0.0, scale = 1.0, opacity = 1.0, turn = 0.0;
    switch (widget.mood) {
      case CompanionMood.cheer:
        if (moving) {
          // gl-sparkle: 0 → 1.1 → .9 → 0.
          final p = (t * 3000 / 1600) % 1.0;
          if (p < .3) {
            scale = 1.1 * p / .3;
          } else if (p < .6) {
            scale = 1.1 - .2 * (p - .3) / .3;
          } else {
            scale = .9 * (1 - (p - .6) / .4);
          }
          opacity = p < .6
              ? (p / .3).clamp(0.0, 1.0)
              : (1 - (p - .6) / .2).clamp(0.0, 1.0);
          turn = _deg(40 * p);
        }
      case CompanionMood.think:
      case CompanionMood.sleep:
        if (moving) dy = -8 * wave * k;
      case CompanionMood.sad:
        if (moving) dx = (-3 + 6 * wave) * k;
      case CompanionMood.oops:
        if (moving) {
          final p = t;
          dy = p < .3 ? 0 : 18 * k * (p - .3) / .7;
          opacity = p < .3 ? p / .3 * .4 : (p < .4 ? 1 : 1 - (p - .4) / .6);
        }
      default:
        break;
    }
    return Positioned(
      left: rect.left + dx,
      top: rect.top + dy,
      width: rect.width,
      height: rect.height,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform.rotate(
          angle: turn,
          child: Transform.scale(
            scale: scale,
            child: Image.asset(asset, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  static const _sadFilter = ColorFilter.matrix(<double>[
    // Saturation 0.55 (luminance weights 0.2126 / 0.7152 / 0.0722).
    0.6457, 0.3218, 0.0325, 0, 0, //
    0.0957, 0.8718, 0.0325, 0, 0, //
    0.0957, 0.3218, 0.5825, 0, 0, //
    0, 0, 0, 1, 0,
  ]);

  static const _sleepFilter = ColorFilter.matrix(<double>[
    // Brightness 0.82.
    0.82, 0, 0, 0, 0, //
    0, 0.82, 0, 0, 0, //
    0, 0, 0.82, 0, 0, //
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 3;
    final asset = CompanionView.assetFor(widget.hero, widget.mood);
    final label = widget.semanticLabel ??
        context.l10n.companionSemantics(widget.hero.name(context.l10n));
    Widget image = Image.asset(
      asset,
      key: ValueKey(asset),
      width: size,
      height: size,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      cacheWidth: (size * dpr).round().clamp(64, 768),
      excludeFromSemantics: true,
    );
    if (widget.mood == CompanionMood.sad) {
      image = ColorFiltered(colorFilter: _sadFilter, child: image);
    } else if (widget.mood == CompanionMood.sleep) {
      image = ColorFiltered(colorFilter: _sleepFilter, child: image);
    }
    image = AnimatedSwitcher(
      duration: AppMotion.orInstant(context, const Duration(milliseconds: 200)),
      child: KeyedSubtree(key: ValueKey(asset), child: image),
    );

    final listenable = Listenable.merge([if (_loop != null) _loop!, _once]);
    final propAsset =
        widget.showProp ? CompanionView.propFor(widget.mood) : null;
    final propRect = _propRect();

    final body = AnimatedBuilder(
      animation: listenable,
      builder: (context, child) {
        final t = _loop?.value ?? 0;
        final o = _once.value;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Transform(
                alignment: const Alignment(0, .84),
                transform: _body(t, o),
                child: child,
              ),
            ),
            if (propAsset != null && propRect != null)
              _prop(t, propRect, propAsset),
          ],
        );
      },
      child: image,
    );

    final view = SizedBox(width: size, height: size, child: body);
    if (widget.decorative) return ExcludeSemantics(child: view);
    return Semantics(
        image: true, label: label, child: ExcludeSemantics(child: view));
  }
}
