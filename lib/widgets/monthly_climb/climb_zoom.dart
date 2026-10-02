import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/widgets.dart';

import '../../models/climb_theme.dart';

import 'climb_camera.dart';
import 'climb_route.dart';

/// How a zoom ended (Batch 6, M16). The names are `month_zoom_ended`'s
/// `outcome` values (M19).
enum ClimbZoomOutcome {
  completed('completed'),

  /// A tap on the mountain card jumped it to its last frame.
  skipped('skipped'),

  /// Reduce Motion: a short cross-fade instead of the zoom.
  reduceMotion('reduce_motion'),

  /// The Daily Test was opened during it; it jumped to its last frame.
  dailyTestOpened('daily_test_opened');

  final String wireName;
  const ClimbZoomOutcome(this.wireName);
}

/// What started a zoom (M19 `trigger`).
enum ClimbZoomTrigger {
  monthChange('month_change'),
  firstRun('first_run');

  final String wireName;
  const ClimbZoomTrigger(this.wireName);
}

/// The K-c framing (scene art Batch 0 §3, Batch 6): the whole image fitted
/// to the window's height, centred across, over its blurred copy
/// (`ClimbTheme.kcBackdropFor`, M22). Only the start of the zoom; the daily
/// framing is [ClimbCamera].
abstract final class ClimbOverview {
  /// Points per image width in K-c, the same at every width.
  static double get scale =>
      ClimbCamera.windowHeight / ClimbRoute.sceneSize.height;

  /// The empty band on each side of the image in a [width]-point window.
  static double band(double width) =>
      (width - ClimbRoute.sceneSize.width * scale) / 2;

  /// Where the blurred backdrop goes in the scene layer (the image's own
  /// points in the daily framing): exactly the window at K-c, so the
  /// transform that brings the layer to K-c makes it fill the window.
  static Rect backdropRect(ClimbCamera camera) {
    final s0 = scale / camera.scale;
    return Rect.fromLTWH(-band(camera.width) / s0, 0, camera.width / s0,
        ClimbCamera.windowHeight / s0);
  }

  static ImageProvider Function(ClimbTheme, Brightness)? _backdropForTesting;

  /// Debug builds only: another image for the backdrop, for measuring
  /// tools (renders of other blur strengths). Ignored in profile and
  /// release builds.
  static set debugBackdropOverride(
          ImageProvider Function(ClimbTheme, Brightness)? value) =>
      _backdropForTesting = value;

  /// The backdrop's image for [theme] in [brightness].
  static ImageProvider backdropImage(ClimbTheme theme, Brightness brightness) =>
      (kDebugMode ? _backdropForTesting?.call(theme, brightness) : null) ??
      AssetImage(theme.kcBackdropFor(brightness));

  /// The transform applied to the scene layer as drawn in the daily
  /// framing (the camera's [camera] scale, at [offset]) to show it at
  /// progress [t]: 0 is K-c, 1 the daily framing (the identity). Scale and
  /// translation are interpolated together, in window coordinates.
  static Matrix4 transform(ClimbCamera camera, Offset offset, double t) {
    final s0 = scale / camera.scale;
    // A daily point p (window) is at s0 · (p + offset) + (band, 0) in K-c.
    final tx0 = s0 * offset.dx + band(camera.width);
    final ty0 = s0 * offset.dy;
    final s = s0 + (1 - s0) * t;
    return Matrix4.diagonal3Values(s, s, 1)
      ..setTranslationRaw(tx0 * (1 - t), ty0 * (1 - t), 0);
  }
}

/// Runs a zoom from K-c to the daily framing (Batch 6, M6, M14, M16): holds
/// K-c (behind the month card), then after [pause] plays [duration], or,
/// with Reduce Motion, a [reduceMotionFade] cross-fade. Home owns it and
/// hands [progress] to `MonthlyMountain` while [active].
///
/// A run always ends, whatever happens: [skip], [dailyTestOpened], the
/// "already played" flag, or [dispose] all complete its future, so a chain
/// waiting on it (the first run: zoom → step → Premium) never stalls.
class ClimbZoomController extends ChangeNotifier {
  /// The zoom's length (M6). Default 1.8 s; 1.2, 1.8 and 2.5 s are to be
  /// tried on a device.
  static const duration = Duration(milliseconds: 1800);

  /// The pause between the month card closing and the zoom.
  static const pause = Duration(milliseconds: 300);

  /// Reduce Motion's cross-fade from K-c to the daily framing.
  static const reduceMotionFade = Duration(milliseconds: 250);

  /// The zoom's easing.
  static const curve = Curves.easeInOutCubic;

  ClimbZoomController({required TickerProvider vsync})
      : _t = AnimationController(vsync: vsync, value: 1);

  final AnimationController _t;
  Timer? _pauseTimer;
  Completer<ClimbZoomOutcome?>? _run;
  bool _active = false;
  bool _playing = false;
  bool _crossFade = false;
  ClimbZoomTrigger? _trigger;

  /// 0 (K-c) to 1 (daily), eased.
  Animation<double> get progress => _progress;
  late final Animation<double> _progress =
      CurvedAnimation(parent: _t, curve: curve);

  /// Whether the scene shows a zoom's frame (holding K-c, pausing or
  /// playing).
  bool get active => _active;

  /// Whether the zoom is pausing or playing: a tap on the mountain skips
  /// it then.
  bool get running => _run != null;

  /// Whether this run is Reduce Motion's cross-fade.
  bool get crossFade => _crossFade;

  ClimbZoomTrigger? get trigger => _trigger;

  /// Shows K-c and keeps it there (behind the month card, or before the
  /// first run's zoom).
  void hold(ClimbZoomTrigger trigger) {
    _trigger = trigger;
    _t.value = 0;
    if (!_active) {
      _active = true;
      notifyListeners();
    }
  }

  /// Plays the zoom: [claim] first (the "zoom started" record, M6: claimed
  /// as it starts, so it never plays twice; false means it already played
  /// and the view jumps to the daily framing with a null outcome), then
  /// the [pause], then the zoom or, with [reduceMotion], the cross-fade.
  /// Completes with how it ended.
  Future<ClimbZoomOutcome?> run({
    required ClimbZoomTrigger trigger,
    required bool reduceMotion,
    required Future<bool> Function() claim,
  }) async {
    if (_run != null) return _run!.future;
    final run = _run = Completer<ClimbZoomOutcome?>();
    hold(trigger);
    // [running] changed: a tap on the mountain skips from now on.
    notifyListeners();
    bool claimed;
    try {
      claimed = await claim();
    } catch (_) {
      claimed = false;
    }
    if (run.isCompleted) return run.future;
    if (!claimed) {
      _finish(null);
      return run.future;
    }
    if (_crossFade != reduceMotion) {
      _crossFade = reduceMotion;
      notifyListeners();
    }
    _pauseTimer = Timer(pause, () {
      if (run.isCompleted) return;
      _playing = true;
      _t.duration = reduceMotion ? reduceMotionFade : duration;
      _t.forward(from: 0).then((_) {
        if (!run.isCompleted) {
          _finish(reduceMotion
              ? ClimbZoomOutcome.reduceMotion
              : ClimbZoomOutcome.completed);
        }
      }, onError: (_) {});
    });
    return run.future;
  }

  /// A tap on the mountain card: the last frame at once.
  void skip() {
    if (_run != null) _finish(ClimbZoomOutcome.skipped);
  }

  /// The Daily Test was opened: the last frame at once (M16). Also ends a
  /// zoom that is only holding.
  void dailyTestOpened() {
    if (_run != null) {
      _finish(ClimbZoomOutcome.dailyTestOpened);
    } else if (_active) {
      _t.value = 1;
      _active = false;
      notifyListeners();
    }
  }

  /// Ends a hold that will not be played (the card could not be shown).
  void release() {
    if (_run != null || !_active) return;
    _t.value = 1;
    _active = false;
    notifyListeners();
  }

  void _finish(ClimbZoomOutcome? outcome) {
    _pauseTimer?.cancel();
    _t.stop();
    _t.value = 1;
    _active = false;
    _playing = false;
    _crossFade = false;
    final run = _run;
    _run = null;
    notifyListeners();
    run?.complete(outcome);
  }

  /// Whether the zoom is moving now (after the pause).
  @visibleForTesting
  bool get playing => _playing;

  @override
  void dispose() {
    _pauseTimer?.cancel();
    final run = _run;
    _run = null;
    run?.complete(null);
    _t.dispose();
    super.dispose();
  }
}
