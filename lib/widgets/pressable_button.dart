import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../motion.dart';
import '../theme.dart';
import '../utils/haptics.dart';

/// The fill of a [PressableButton] (V00-MotionSystem).
enum ButtonTone {
  /// The orange main action (`orange` / `orangeDeep` lip / `onOrange`).
  orange,

  /// The navy action (`navy` / `navyDeep` lip / white).
  navy,

  /// A correct-answer action (`greenDeep`).
  green,

  /// A wrong-answer acknowledgement (V09's "Got it", `red`).
  red,

  /// The secondary, outlined action: card fill, 2 px border, a lip.
  outline,

  /// A text action: no fill, no lip (still moves on press).
  text,

  /// A destructive text action (red text, no fill).
  danger,
}

/// The haptic a [PressableButton] plays on tap (SPEC §3.4).
enum ButtonHaptic { none, selection, light, medium }

/// The app's 3D button (SPEC §3.2): height 56 (52 inside cards), radius 18,
/// a 5 px bottom lip in the deep tone; on press it moves down 4 px and the
/// lip shrinks to 1 px in 80 ms. Optional shine sweep (a 3 s loop, the main
/// CTA of a screen only), a pulse ring behind it (Daily Test card), and a
/// busy state with three dots (R11's retry).
///
/// [onPressed] null → disabled (the disabled fill and lip).
class PressableButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final ButtonTone tone;
  final double height;
  final IconData? leadingIcon;
  final IconData? trailingIcon;

  /// A widget before the label instead of [leadingIcon] (the wheel icon of
  /// "Try my luck").
  final Widget? leading;

  /// Full width (default) or as wide as its content.
  final bool expand;
  final bool shine;
  final bool pulse;
  final bool busy;
  final ButtonHaptic haptic;

  /// The label's semantics when it differs from [label].
  final String? semanticLabel;

  /// Fades the label in when it changes (R02's live button text).
  final bool crossFadeLabel;

  /// Whether the button's own height includes room for its lip (the
  /// default), or the lip draws outside it (a button in a fixed card row,
  /// X05's 52 pt slot).
  final bool reserveLip;

  const PressableButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.tone = ButtonTone.navy,
    this.height = 56,
    this.leadingIcon,
    this.trailingIcon,
    this.leading,
    this.expand = true,
    this.shine = false,
    this.pulse = false,
    this.busy = false,
    this.haptic = ButtonHaptic.medium,
    this.semanticLabel,
    this.crossFadeLabel = false,
    this.reserveLip = true,
  });

  /// The lip under the button at rest and pressed.
  static const double lip = 5;
  static const double pressedLip = 1;
  static const double travel = 4;
  static const double radius = 18;

  /// The shine band's layer (tests).
  static const shineKey = ValueKey('pressable_button_shine');

  @override
  State<PressableButton> createState() => _PressableButtonState();
}

class _PressableButtonState extends State<PressableButton>
    with TickerProviderStateMixin {
  bool _pressed = false;
  AnimationController? _loop;

  bool get _enabled => widget.onPressed != null && !widget.busy;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncLoop();
  }

  @override
  void didUpdateWidget(PressableButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncLoop();
  }

  void _syncLoop() {
    final wanted = (widget.shine || widget.pulse || widget.busy) &&
        AppMotion.loopsOn(context);
    if (wanted && _loop == null) {
      _loop = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 1800))
        ..repeat();
    } else if (!wanted && _loop != null) {
      _loop!.dispose();
      _loop = null;
    }
  }

  @override
  void dispose() {
    _loop?.dispose();
    super.dispose();
  }

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  void _tap() {
    if (!_enabled) return;
    switch (widget.haptic) {
      case ButtonHaptic.none:
        break;
      case ButtonHaptic.selection:
        HapticMap.selection();
      case ButtonHaptic.light:
        HapticMap.light();
      case ButtonHaptic.medium:
        HapticMap.medium();
    }
    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final theme = Theme.of(context);
    final (fill, lipColor, fg, border) = _colors(c, theme);
    final flat =
        widget.tone == ButtonTone.text || widget.tone == ButtonTone.danger;
    final pressed = _pressed && _enabled;
    final lip = flat
        ? 0.0
        : (pressed ? PressableButton.pressedLip : PressableButton.lip);
    final dy =
        flat ? (pressed ? 2.0 : 0.0) : (pressed ? PressableButton.travel : 0.0);
    final duration = AppMotion.orInstant(context, AppMotion.press);
    final textStyle = theme.textTheme.titleMedium!
        .withWeight(FontWeight.w900)
        .copyWith(color: fg, fontSize: 17, height: 1.15, letterSpacing: -.2);

    Widget label = Text(
      widget.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: textStyle,
    );
    if (widget.crossFadeLabel) {
      label = AnimatedSwitcher(
        duration: AppMotion.orInstant(context, AppMotion.base),
        child: KeyedSubtree(key: ValueKey(widget.label), child: label),
      );
    }
    final content = widget.busy
        ? _BusyDots(color: fg, animation: _loop)
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.leading != null) ...[
                widget.leading!,
                const SizedBox(width: 10),
              ] else if (widget.leadingIcon != null) ...[
                Icon(widget.leadingIcon, color: fg, size: 20),
                const SizedBox(width: 10),
              ],
              Flexible(child: label),
              if (widget.trailingIcon != null) ...[
                const SizedBox(width: 10),
                Icon(widget.trailingIcon, color: fg, size: 20),
              ],
            ],
          );

    Widget face = AnimatedContainer(
      duration: duration,
      curve: Curves.easeOut,
      height: widget.height,
      transform: Matrix4.translationValues(0, dy, 0),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(PressableButton.radius),
        border: border == null ? null : Border.all(color: border, width: 2),
        boxShadow: lip == 0
            ? null
            : [BoxShadow(color: lipColor, offset: Offset(0, lip))],
      ),
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      child: content,
    );
    // The shine over the whole face (not the label's box), clipped to it.
    if (widget.shine && _loop != null && _enabled) {
      face = Stack(
        children: [
          face,
          Positioned.fill(
            child: Transform.translate(
              offset: Offset(0, dy),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(PressableButton.radius),
                child: ButtonShine(
                    key: PressableButton.shineKey, animation: _loop!),
              ),
            ),
          ),
        ],
      );
    }

    if (widget.pulse && _loop != null && _enabled) {
      face = Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: _PulseRing(animation: _loop!, color: fill)),
          face,
        ],
      );
    }

    final button = Semantics(
      button: true,
      enabled: _enabled,
      label: widget.semanticLabel ?? widget.label,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _enabled ? (_) => _setPressed(true) : null,
          onTapCancel: () => _setPressed(false),
          onTapUp: (_) => _setPressed(false),
          onTap: _enabled ? _tap : null,
          child: Padding(
            // Room for the lip so it is not clipped by a parent.
            padding: EdgeInsets.only(
                bottom: flat || !widget.reserveLip ? 0 : PressableButton.lip),
            child: face,
          ),
        ),
      ),
    );
    return widget.expand
        ? SizedBox(width: double.infinity, child: button)
        : IntrinsicWidth(child: button);
  }

  (Color fill, Color lip, Color fg, Color? border) _colors(
      AppColors c, ThemeData theme) {
    if (!_enabled && !widget.busy) {
      return switch (widget.tone) {
        ButtonTone.text || ButtonTone.danger => (
            Colors.transparent,
            Colors.transparent,
            c.disabledLabel,
            null
          ),
        _ => (c.disabledFill, c.disabledLip, c.disabledLabel, null),
      };
    }
    return switch (widget.tone) {
      ButtonTone.orange => (c.orange, c.orangeDeep, c.onOrange, null),
      ButtonTone.navy => (c.navy, c.navyDeep, c.onNavy, null),
      ButtonTone.green => (c.greenDeep, c.greenLip, c.onNavy, null),
      ButtonTone.red => (c.red, c.redLip, c.onNavy, null),
      ButtonTone.outline => (c.card, c.lip, c.text, c.line),
      ButtonTone.text => (
          Colors.transparent,
          Colors.transparent,
          theme.colorScheme.secondary,
          null
        ),
      // Red text on the page or a card: the text token (SY03, v11).
      ButtonTone.danger => (
          Colors.transparent,
          Colors.transparent,
          c.redText,
          null
        ),
    };
  }
}

/// The shine every shining button uses (SPEC §3.2, v11; one shared
/// implementation, fix round 3, B4): a diagonal band the full height of the
/// button, 38 % of its width, skewed −20°, white 0 → 50 % → 0, travelling
/// from −140 % to +320 % of its own width in the first 55 % of [animation]
/// (a 3 s loop), then resting out of view. It fills its parent, which must
/// be the whole button face; the caller clips it to the button's shape.
/// Never a small square (the device build drew one on V05 and V06: the band
/// was laid out in the label's box).
class ButtonShine extends StatelessWidget {
  final Animation<double> animation;
  const ButtonShine({super.key, required this.animation});

  /// The band's width, a share of the button's.
  static const widthShare = .38;

  /// The skew, in degrees (negative leans the top to the right).
  static const skewDegrees = -20.0;

  /// The band's peak opacity.
  static const peak = .5;

  /// Where the band's left edge starts and ends, in band widths, and the
  /// share of the loop the sweep takes.
  static const from = -1.4, to = 3.2, sweep = .55;

  /// The band's left edge for a loop value [t], in points, on a button
  /// [width] wide.
  static double leftAt(double t, double width) {
    final u = (t / sweep).clamp(0.0, 1.0);
    return (from + (to - from) * u) * width * widthShare;
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth;
        final band = w * widthShare;
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) => Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                left: leftAt(animation.value, w),
                top: 0,
                bottom: 0,
                width: band,
                child: child!,
              ),
            ],
          ),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.skewX(skewDegrees * math.pi / 180),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  Colors.white.withValues(alpha: 0),
                  Colors.white.withValues(alpha: peak),
                  Colors.white.withValues(alpha: 0),
                ]),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// The main-CTA effects for a button that is not a [PressableButton] (the
/// paywall's FilledButton): the shine sweep inside it (`gl-shine`, 3 s) and
/// the pulse ring behind it (`gl-pulse`, 1.8 s). Only while [enabled] and
/// loops run (not under Reduce Motion).
class CtaGlow extends StatefulWidget {
  final bool enabled;
  final Color color;
  final double radius;
  final Widget child;

  const CtaGlow({
    super.key,
    required this.enabled,
    required this.color,
    required this.radius,
    required this.child,
  });

  /// The shine band and the pulse ring (tests).
  static const shineKey = ValueKey('cta_glow_shine');
  static const pulseKey = ValueKey('cta_glow_pulse');

  @override
  State<CtaGlow> createState() => _CtaGlowState();
}

class _CtaGlowState extends State<CtaGlow> with TickerProviderStateMixin {
  AnimationController? _shine;
  AnimationController? _pulse;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(CtaGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final on = widget.enabled && AppMotion.loopsOn(context);
    if (on && _shine == null) {
      _shine = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 3000))
        ..repeat();
      _pulse = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 1800))
        ..repeat();
    } else if (!on && _shine != null) {
      _shine!.dispose();
      _pulse!.dispose();
      _shine = null;
      _pulse = null;
    }
  }

  @override
  void dispose() {
    _shine?.dispose();
    _pulse?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shine = _shine, pulse = _pulse;
    if (shine == null || pulse == null) return widget.child;
    final radius = BorderRadius.circular(widget.radius);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: _PulseRing(
              key: CtaGlow.pulseKey,
              animation: pulse,
              color: widget.color,
              radius: widget.radius,
              lip: 0),
        ),
        widget.child,
        Positioned.fill(
          child: ClipRRect(
            borderRadius: radius,
            child: ButtonShine(key: CtaGlow.shineKey, animation: shine),
          ),
        ),
      ],
    );
  }
}

/// A ring that grows out of the button and fades (`gl-pulse`, 1.8 s loop).
class _PulseRing extends StatelessWidget {
  final Animation<double> animation;
  final Color color;
  final double radius;
  final double lip;
  const _PulseRing({
    super.key,
    required this.animation,
    required this.color,
    this.radius = PressableButton.radius,
    this.lip = PressableButton.lip,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final t = animation.value;
          return Transform.scale(
            scaleX: 1 + .08 * t,
            scaleY: 1 + .45 * t,
            child: Padding(
              padding: EdgeInsets.only(bottom: lip),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .45 * (1 - t)),
                  borderRadius: BorderRadius.circular(radius),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Three dots that blink in turn (`gl-dots`), the busy state.
class _BusyDots extends StatelessWidget {
  final Color color;
  final Animation<double>? animation;
  const _BusyDots({required this.color, required this.animation});

  @override
  Widget build(BuildContext context) {
    Widget dot(int i) {
      final a = animation;
      if (a == null) {
        return _dot(.6);
      }
      return AnimatedBuilder(
        animation: a,
        builder: (context, _) {
          final phase = (a.value - i * .15) % 1.0;
          final o = phase < .4 ? .2 + 2 * phase : (1 - (phase - .4) * 1.33);
          return _dot(o.clamp(.2, 1.0));
        },
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: dot(i),
          ),
      ],
    );
  }

  Widget _dot(double opacity) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: color.withValues(alpha: opacity),
          shape: BoxShape.circle,
        ),
      );
}

/// A tappable card that moves down [travel] px on press (weak spot cards,
/// topic cards) and plays its [haptic].
///
/// With [focusable] it also takes keyboard focus in reading order (Tab),
/// Enter or Space activates it, and a [focusRadius] ring in the brand
/// orange shows only while it has keyboard focus: a touch never changes
/// its look (UI polish fix round 1, D9-4).
class PressableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double travel;
  final ButtonHaptic haptic;
  final String? semanticLabel;
  final bool focusable;
  final double focusRadius;

  const PressableCard({
    super.key,
    required this.child,
    required this.onTap,
    this.travel = 2,
    this.haptic = ButtonHaptic.light,
    this.semanticLabel,
    this.focusable = false,
    this.focusRadius = 18,
  });

  /// The ring shown with keyboard focus.
  static const focusRingKey = ValueKey('pressable_card_focus_ring');

  @override
  State<PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<PressableCard> {
  bool _pressed = false;

  /// Keyboard focus is on the card (shown only in keyboard mode).
  bool _focusRing = false;

  void _set(bool v) {
    if (_pressed != v && mounted) setState(() => _pressed = v);
  }

  void _activate() {
    switch (widget.haptic) {
      case ButtonHaptic.none:
        break;
      case ButtonHaptic.selection:
        HapticMap.selection();
      case ButtonHaptic.light:
        HapticMap.light();
      case ButtonHaptic.medium:
        HapticMap.medium();
    }
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    Widget child = AnimatedContainer(
      duration: AppMotion.orInstant(context, AppMotion.press),
      transform: Matrix4.translationValues(0, _pressed ? widget.travel : 0, 0),
      child: widget.child,
    );
    if (widget.focusable && _focusRing) {
      child = DecoratedBox(
        key: PressableCard.focusRingKey,
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.focusRadius),
          border: Border.all(
              color: AppColors.of(context).orange,
              width: 3,
              strokeAlign: BorderSide.strokeAlignOutside),
        ),
        child: child,
      );
    }
    child = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: enabled ? _activate : null,
      child: child,
    );
    if (widget.focusable) {
      child = FocusableActionDetector(
        enabled: enabled,
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
            _activate();
            return null;
          }),
        },
        onShowFocusHighlight: (v) {
          if (mounted && v != _focusRing) setState(() => _focusRing = v);
        },
        child: child,
      );
    }
    if (widget.semanticLabel != null) {
      child = Semantics(
        button: enabled,
        label: widget.semanticLabel,
        child: child,
      );
    }
    return child;
  }
}
