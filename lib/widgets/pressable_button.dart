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
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.shine && _loop != null && _enabled)
            Positioned.fill(child: _Shine(animation: _loop!)),
          content,
        ],
      ),
    );

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
      ButtonTone.outline => (c.card, c.lip, c.text, c.line),
      ButtonTone.text => (
          Colors.transparent,
          Colors.transparent,
          theme.colorScheme.secondary,
          null
        ),
      ButtonTone.danger => (
          Colors.transparent,
          Colors.transparent,
          c.red,
          null
        ),
    };
  }
}

/// A light band that sweeps across the button (V00: `gl-shine`, 3 s loop:
/// the sweep takes the first 55 %).
class _Shine extends StatelessWidget {
  final Animation<double> animation;
  const _Shine({required this.animation});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final t = (animation.value / .55).clamp(0.0, 1.0);
          return FractionalTranslation(
            translation: Offset(-1.4 + 4.6 * t, 0),
            child: FractionallySizedBox(
              widthFactor: .3,
              alignment: Alignment.centerLeft,
              child: Transform(
                transform: Matrix4.skewX(-.35),
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      Color(0x00FFFFFF),
                      Color(0x66FFFFFF),
                      Color(0x00FFFFFF),
                    ]),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A ring that grows out of the button and fades (`gl-pulse`, 1.8 s loop).
class _PulseRing extends StatelessWidget {
  final Animation<double> animation;
  final Color color;
  const _PulseRing({required this.animation, required this.color});

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
              padding: const EdgeInsets.only(bottom: PressableButton.lip),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .45 * (1 - t)),
                  borderRadius: BorderRadius.circular(PressableButton.radius),
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
class PressableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double travel;
  final ButtonHaptic haptic;
  final String? semanticLabel;

  const PressableCard({
    super.key,
    required this.child,
    required this.onTap,
    this.travel = 2,
    this.haptic = ButtonHaptic.light,
    this.semanticLabel,
  });

  @override
  State<PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<PressableCard> {
  bool _pressed = false;

  void _set(bool v) {
    if (_pressed != v && mounted) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    Widget child = AnimatedContainer(
      duration: AppMotion.orInstant(context, AppMotion.press),
      transform: Matrix4.translationValues(0, _pressed ? widget.travel : 0, 0),
      child: widget.child,
    );
    child = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: enabled
          ? () {
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
          : null,
      child: child,
    );
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
