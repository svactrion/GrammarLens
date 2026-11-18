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
}

/// What a companion does between its one-shot moments.
enum CompanionAmbient {
  /// The mood's own loop (SPEC §3.5).
  mood,

  /// `gl-hop`: a hop every 1.2 s (the Daily Test card, the paywall's middle
  /// companion, PW05).
  hop,

  /// `gl-float`: up 8 px and back every 3.2 s (the paywall's side
  /// companions).
  float,

  /// No loop of its own: a parent moves it (Welcome's trio).
  none,
}

/// One frame of a companion's body motion: [dy] in points (negative is
/// up), [turn] in degrees around the feet, and a scale.
@immutable
class CompanionFrame {
  final double dy;
  final double turn;
  final double scaleX;
  final double scaleY;

  const CompanionFrame(
      {this.dy = 0, this.turn = 0, this.scaleX = 1, this.scaleY = 1});

  static const rest = CompanionFrame();

  @override
  String toString() =>
      'CompanionFrame(dy: $dy, turn: $turn, scale: $scaleX × $scaleY)';
}

/// The one companion widget (V00-CompanionSystem, X01, X03): the hero in a
/// mood, at [size] × [size]. Props sit at the top right of the head and may
/// draw outside the square.
///
/// Motion per mood (SPEC §3.5 as minimums, the boards' keyframes; fix round
/// 2 made every loop visible on a phone): idle breathes (scale 1 ↔ 1.04)
/// and floats 6 px (±3), 3 s; wave sways like `gl-wave` (−9°, +7°, −6°,
/// +3°, 2.2 s) and bobs 4 px; cheer hops twice (`gl-hop`, 16 px, 600 ms
/// each) then breathes, every 2.4 s, with sparkles 0 → 1.1 → 0; think tilts
/// +3° ↔ −6° (2.4 s); inspect tilts ±4° (`gl-tilt`, 2.4 s); sad droops (±3°,
/// 4 px down, 2.6 s; saturation 0.55); sleep breathes (scale 1.02 × 1.05,
/// 3.6 s; brightness 0.82) while its Zzz rises and fades (`gl-zz2`, 2.4 s);
/// oops shakes its head ±8° twice in 360 ms while a sweat drop falls.
/// [ambient] can replace the mood's loop (hop, float, none). Under Reduce
/// Motion (and while loops are off) only the still pose and its prop show;
/// the one-shot hops and shake are skipped under Reduce Motion.
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
  /// the Daily Test card waiting for its test (X05, V15). Same as
  /// `ambient: CompanionAmbient.hop`.
  final bool hopping;

  /// The loop between one-shot moments; [hopping] wins.
  final CompanionAmbient ambient;

  /// How long a change of pose cross-fades (V24s: waking 200 ms, falling
  /// asleep again 400 ms). The new pose also scales 0.96 → 1 (§3.3, v11);
  /// under Reduce Motion it is a 150 ms fade ([reducedPoseSwitch]).
  final Duration poseSwitch;

  /// How many hops cheer's one-shot makes when the pose appears (§3.5:
  /// two; V04's greeting: one), 300 ms each.
  final int cheerHops;

  /// Reduce Motion's pose change: a plain fade (§3.3, v11).
  static const reducedPoseSwitch = Duration(milliseconds: 150);

  /// The new pose's scale at the start of its cross-fade (§3.3, v11).
  static const poseSwitchScale = .96;

  /// The pose image's cross-fade (tests read its scale).
  static ValueKey<String> poseKey(String asset) => ValueKey('pose_$asset');

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
    this.ambient = CompanionAmbient.mood,
    this.poseSwitch = const Duration(milliseconds: 200),
    this.cheerHops = 2,
  });

  /// The body's transform (tests read its motion).
  static const bodyKey = ValueKey('companion_body');

  /// The prop (tests read the Zzz and the sparkle).
  static const propKey = ValueKey('companion_prop');

  /// The loop's length for [mood] under [ambient].
  static Duration periodOf(CompanionMood mood,
          [CompanionAmbient ambient = CompanionAmbient.mood]) =>
      switch (ambient) {
        CompanionAmbient.hop => const Duration(milliseconds: 1200),
        CompanionAmbient.float => const Duration(milliseconds: 3200),
        CompanionAmbient.none => Duration.zero,
        CompanionAmbient.mood => switch (mood) {
            CompanionMood.idle => const Duration(milliseconds: 3000),
            CompanionMood.wave => const Duration(milliseconds: 2200),
            CompanionMood.cheer => const Duration(milliseconds: 2400),
            CompanionMood.think => const Duration(milliseconds: 2400),
            CompanionMood.inspect => const Duration(milliseconds: 2400),
            CompanionMood.sad => const Duration(milliseconds: 2600),
            // The 3.6 s breath twice, the 2.4 s Zzz three times.
            CompanionMood.sleep => const Duration(milliseconds: 7200),
            CompanionMood.oops => const Duration(milliseconds: 1800),
          },
      };

  /// The body's frame at loop phase [t] (0–1 of [periodOf]) for a
  /// companion of [size]; [once] is the one-shot's progress (cheer's hops,
  /// oops's shake; 1 when done) and [looping] whether the loop runs.
  static CompanionFrame frameAt(
    CompanionMood mood,
    double t, {
    double size = 110,
    CompanionAmbient ambient = CompanionAmbient.mood,
    double once = 1,
    bool looping = true,
    int cheerHops = 2,
  }) {
    // Distances follow the size above the boards' 110 pt, never below
    // their points (fix round 2: visible on a phone).
    final k = math.max(1.0, size / 110);
    // 0 → 1 → 0 over [p], smooth (the CSS `ease-in-out` 0/50/100 %).
    double swell(double p) => (1 - math.cos(2 * math.pi * p)) / 2;
    final w = swell(t);

    // The one-shots play whether or not the loop runs (not under Reduce
    // Motion: the widget never starts them there).
    if (once < 1) {
      if (mood == CompanionMood.cheer) {
        return _hop((once * cheerHops) % 1.0, 16 * k);
      }
      if (mood == CompanionMood.oops) {
        final local = (once * 2) % 1.0;
        return CompanionFrame(
            turn: 8 * math.sin(2 * math.pi * local) * (1 - local));
      }
    }
    if (!looping) return CompanionFrame.rest;
    switch (ambient) {
      case CompanionAmbient.hop:
        return _hop(t, 16 * k);
      case CompanionAmbient.float:
        return CompanionFrame(dy: -8 * k * w);
      case CompanionAmbient.none:
        return CompanionFrame.rest;
      case CompanionAmbient.mood:
        break;
    }
    switch (mood) {
      case CompanionMood.idle:
        return CompanionFrame(
            dy: -6 * k * w, scaleX: 1 + .04 * w, scaleY: 1 + .04 * w);
      case CompanionMood.wave:
        return CompanionFrame(dy: -4 * k * w, turn: _waveTurn(t));
      case CompanionMood.cheer:
        // Two hops of 600 ms, then a 1.2 s breath.
        if (t < .5) return _hop((t * 4) % 1.0, 16 * k);
        final b = swell((t - .5) * 2);
        return CompanionFrame(scaleX: 1 + .04 * b, scaleY: 1 + .04 * b);
      case CompanionMood.think:
        return CompanionFrame(dy: -2 * k * w, turn: 3 - 9 * w);
      case CompanionMood.inspect:
        return CompanionFrame(dy: -2 * k * w, turn: -4 + 8 * w);
      case CompanionMood.sad:
        return CompanionFrame(dy: (2 + 2 * w) * k, turn: -3 + 6 * w);
      case CompanionMood.sleep:
        final b = swell((t * 2) % 1.0);
        return CompanionFrame(scaleX: 1 + .02 * b, scaleY: 1 + .05 * b);
      case CompanionMood.oops:
        return CompanionFrame.rest;
    }
  }

  /// `gl-hop` at [p] (0–1): up [height] with a stretch by 30 %, down with a
  /// squash by 50 %, still from 65 %.
  static CompanionFrame _hop(double p, double height) {
    if (p < .3) {
      final k = Curves.easeOut.transform(p / .3);
      return CompanionFrame(
          dy: -height * k, scaleX: 1 - .04 * k, scaleY: 1 + .05 * k);
    }
    if (p < .5) {
      final k = Curves.easeIn.transform((p - .3) / .2);
      return CompanionFrame(
          dy: -height * (1 - k), scaleX: .96 + .1 * k, scaleY: 1.05 - .13 * k);
    }
    if (p < .65) {
      final k = (p - .5) / .15;
      return CompanionFrame(scaleX: 1.06 - .06 * k, scaleY: .92 + .08 * k);
    }
    return CompanionFrame.rest;
  }

  /// `gl-wave`: 0, −9°, +7°, −6°, +3°, 0 at 0/15/30/45/60/75 %, then still.
  static double _waveTurn(double t) {
    const stops = [0.0, .15, .30, .45, .60, .75];
    const turns = [0.0, -9.0, 7.0, -6.0, 3.0, 0.0];
    for (var i = 1; i < stops.length; i++) {
      if (t < stops[i]) {
        final k = Curves.easeInOut
            .transform((t - stops[i - 1]) / (stops[i] - stops[i - 1]));
        return turns[i - 1] + (turns[i] - turns[i - 1]) * k;
      }
    }
    return 0;
  }

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

  Duration _onceDuration(CompanionMood mood) => switch (mood) {
        CompanionMood.cheer => Duration(milliseconds: 300 * widget.cheerHops),
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
    if (oldWidget.mood != widget.mood ||
        oldWidget.hopping != widget.hopping ||
        oldWidget.ambient != widget.ambient) {
      _loop?.dispose();
      _loop = null;
      _syncLoop();
    }
    if (oldWidget.mood != widget.mood || oldWidget.replay != widget.replay) {
      _playOnce();
    }
  }

  CompanionAmbient get _ambient =>
      widget.hopping ? CompanionAmbient.hop : widget.ambient;

  void _syncLoop() {
    final period = CompanionView.periodOf(widget.mood, _ambient);
    final on = AppMotion.loopsOn(context) && period > Duration.zero;
    if (on && _loop == null) {
      _loop = AnimationController(vsync: this, duration: period)..repeat();
    } else if (!on && _loop != null) {
      _loop!.dispose();
      _loop = null;
    }
  }

  void _playOnce() {
    final d = _onceDuration(widget.mood);
    // A running cheer loop starts with its two hops: restart it instead.
    if (widget.mood == CompanionMood.cheer &&
        _ambient == CompanionAmbient.mood &&
        _loop != null) {
      _once.value = 1;
      _loop!
        ..value = 0
        ..repeat();
      return;
    }
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
    final f = CompanionView.frameAt(widget.mood, t,
        size: widget.size,
        ambient: _ambient,
        once: o,
        looping: _loop != null,
        cheerHops: widget.cheerHops);
    return Matrix4.identity()
      ..translateByDouble(0, f.dy, 0, 1)
      ..rotateZ(_deg(f.turn))
      ..scaleByDouble(f.scaleX, f.scaleY, 1, 1);
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
          // gl-sparkle: 0 → 1.1 → .9 → 0, twice per cheer loop.
          final p = _ambient == CompanionAmbient.mood ? (t * 2) % 1.0 : t;
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
        if (moving) dy = -8 * wave * k;
      case CompanionMood.sleep:
        if (moving) {
          // gl-zz2: rises 30 and drifts 14 (at 110 pt), grows .6 → 1.1,
          // fades in by 30 % and out by the end; every 2.4 s.
          final z = (t * 3) % 1.0;
          dx = 14 * z * k;
          dy = -30 * z * k;
          scale = .6 + .5 * z;
          opacity = z < .3 ? z / .3 : 1 - (z - .3) / .7;
        }
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
      key: CompanionView.propKey,
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
    // §3.3 (v11): a change of pose cross-fades, the new pose scaling
    // 0.96 → 1; under Reduce Motion a plain 150 ms fade.
    final reduced = AppMotion.reduced(context);
    final poseKey = CompanionView.poseKey(asset);
    image = AnimatedSwitcher(
      duration: reduced ? CompanionView.reducedPoseSwitch : widget.poseSwitch,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.center,
        children: [...previous, if (current != null) current],
      ),
      transitionBuilder: (child, animation) {
        final incoming = child.key == poseKey;
        return FadeTransition(
          opacity: animation,
          child: reduced || !incoming
              ? child
              : ScaleTransition(
                  scale: Tween(begin: CompanionView.poseSwitchScale, end: 1.0)
                      .animate(animation),
                  child: child,
                ),
        );
      },
      child: KeyedSubtree(key: poseKey, child: image),
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
                key: CompanionView.bodyKey,
                // The boards' `transform-origin: 50% 92%`: the feet.
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
