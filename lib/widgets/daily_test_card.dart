import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../l10n/l10n.dart';
import '../models/avatar.dart';
import '../motion.dart';
import '../theme.dart';
import 'companion_view.dart';
import 'pressable_button.dart';
import 'score_ring.dart';
import 'skeleton.dart';
import 'step_bar.dart';

/// The Daily Test card's state (X05).
enum DailyTestCardState { loading, todo, done }

/// The Daily Test card (X05, SPEC §1.4): one fixed skeleton for loading,
/// waiting and done. Outer 256 high (the width is the column's, 350 on a
/// 390 pt phone), radius 28, a 6 px lip; rows header 28 · gap 20 · content
/// 100 · gap 20 · button 52, padding 18. Finishing the test changes colours
/// and slot contents only, never size or alignment.
///
/// Text never grows the card: every line is one line, truncated with "…";
/// the title shrinks from 26 to 22 before it truncates, and the card's text
/// is not scaled past 1.0 (the rows have fixed heights).
class DailyTestCard extends StatelessWidget {
  final DailyTestCardState state;
  final Avatar hero;

  /// The content row's title and subline (todo / done).
  final String title;
  final String subtitle;

  /// Done: one entry per question, true = correct.
  final List<bool> results;
  final int questionCount;

  /// The button's label (todo / done) and action. Null action: disabled.
  final String buttonLabel;
  final VoidCallback? onPressed;

  /// A light haptic per filled segment when the done bar fills (X05:
  /// "back on Home after finishing: light per filled segment").
  final ValueChanged<int>? onSegmentFilled;

  const DailyTestCard({
    super.key,
    required this.state,
    required this.hero,
    this.title = '',
    this.subtitle = '',
    this.results = const [],
    this.questionCount = 5,
    this.buttonLabel = '',
    this.onPressed,
    this.onSegmentFilled,
  });

  static const double height = 256;
  static const double radius = 28;
  static const double lip = 6;
  static const double padding = 18;
  static const double headerHeight = 28;
  static const double contentHeight = 100;
  static const double buttonHeight = 52;
  static const double rowGap = 20;
  static const double slot = 100;
  static const double barWidth = 140;

  static const buttonKey = ValueKey('daily_test_card_button');

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final (bg, lipColor) = switch (state) {
      DailyTestCardState.loading => (c.orangeSoft, c.orangeSoftLip),
      DailyTestCardState.todo => (c.orange, c.orangeDeep),
      DailyTestCardState.done => (c.navy, c.navyDeep),
    };
    final colorDuration = AppMotion.orInstant(context, AppMotion.slow);
    final fade = AppMotion.orInstant(context, AppMotion.base);

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.0,
      child: AnimatedContainer(
        duration: colorDuration,
        curve: Curves.easeInOut,
        height: height,
        padding: const EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [BoxShadow(color: lipColor, offset: const Offset(0, lip))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: headerHeight, child: _header(context, c, fade)),
            const SizedBox(height: rowGap),
            SizedBox(
              height: contentHeight,
              child: Row(
                children: [
                  Expanded(child: _texts(context, c, fade)),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: slot,
                    height: slot,
                    child: AnimatedSwitcher(
                      duration: fade,
                      child: KeyedSubtree(
                        key: ValueKey(state == DailyTestCardState.done),
                        child: _slot(context, c),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: rowGap),
            SizedBox(height: buttonHeight, child: _button(context, c, fade)),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, AppColors c, Duration fade) {
    final theme = Theme.of(context);
    final labelColor = switch (state) {
      DailyTestCardState.loading => c.orangeDeep,
      DailyTestCardState.todo => c.onOrange,
      DailyTestCardState.done => c.onNavy,
    };
    final Widget chip = switch (state) {
      DailyTestCardState.loading =>
        const SkeletonBar(width: 104, height: 28, radius: 14),
      DailyTestCardState.todo => _Chip(
          label: context.l10n.homeDailyFree,
          background: Colors.white.withValues(alpha: .45),
          foreground: c.onOrange,
        ),
      DailyTestCardState.done => _Chip(
          label: context.l10n.dailyCardDone,
          background: c.green,
          foreground: c.onNavy,
        ),
    };
    return Row(
      children: [
        Expanded(
          child: Text(
            context.l10n.homeDailyEyebrow,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium!
                .withWeight(FontWeight.w900)
                .copyWith(
                    color: labelColor.withValues(alpha: .9),
                    fontSize: 13,
                    letterSpacing: 1.4),
          ),
        ),
        const SizedBox(width: 8),
        AnimatedSwitcher(
          duration: fade,
          child: KeyedSubtree(key: ValueKey(state), child: chip),
        ),
      ],
    );
  }

  Widget _texts(BuildContext context, AppColors c, Duration fade) {
    final theme = Theme.of(context);
    final segments = switch (state) {
      DailyTestCardState.done => [
          for (var i = 0; i < questionCount; i++)
            i < results.length ? (results[i] ? c.green : c.orange) : null,
        ],
      _ => List<Color?>.filled(questionCount, null),
    };
    final track = switch (state) {
      DailyTestCardState.loading => c.orangeDeep.withValues(alpha: .18),
      DailyTestCardState.todo => c.onOrange.withValues(alpha: .18),
      DailyTestCardState.done => Colors.white.withValues(alpha: .18),
    };
    final Widget lines = state == DailyTestCardState.loading
        ? const Column(
            key: ValueKey('loading'),
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SkeletonBar(widthFactor: .8, height: 30, radius: 15),
              SizedBox(height: 6),
              SkeletonBar(widthFactor: .62, height: 18, radius: 9),
            ],
          )
        : Column(
            key: ValueKey(state),
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 30,
                child: _FitTitle(
                  text: title,
                  style: theme.textTheme.headlineMedium!
                      .withWeight(FontWeight.w900)
                      .copyWith(
                        color: state == DailyTestCardState.done
                            ? c.onNavy
                            : c.onOrange,
                        fontSize: 26,
                        height: 30 / 26,
                        letterSpacing: -.6,
                      ),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 18,
                child: Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium!
                      .withWeight(FontWeight.w700)
                      .copyWith(
                        fontSize: 14,
                        height: 18 / 14,
                        color: state == DailyTestCardState.done
                            ? c.onNavyMuted
                            : c.onOrange,
                      ),
                ),
              ),
            ],
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: 54,
          child: AnimatedSwitcher(
            duration: fade,
            layoutBuilder: (current, previous) => Stack(
              alignment: AlignmentDirectional.centerStart,
              children: [...previous, if (current != null) current],
            ),
            child: lines,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: barWidth,
          child: StepBar(
            segments: segments,
            track: track,
            height: 8,
            gap: 5,
            onFilled: onSegmentFilled,
          ),
        ),
      ],
    );
  }

  Widget _slot(BuildContext context, AppColors c) {
    return switch (state) {
      DailyTestCardState.loading => CompanionView(
          hero: hero, mood: CompanionMood.think, size: slot, showProp: false),
      DailyTestCardState.todo => CompanionView(
          hero: hero, mood: CompanionMood.idle, size: slot, hopping: true),
      DailyTestCardState.done => Center(
          child: ScoreRing(
            value: questionCount == 0
                ? 0
                : results.where((r) => r).length / questionCount,
            size: slot,
            stroke: 12,
            color: c.orange,
            track: Colors.white.withValues(alpha: .18),
            semanticLabel: context.l10n.dailyCardScoreSemantics(
                results.where((r) => r).length, questionCount),
            center: ScoreRing.fraction(
                context, results.where((r) => r).length, questionCount,
                color: c.onNavy),
          ),
        ),
    };
  }

  Widget _button(BuildContext context, AppColors c, Duration fade) {
    final Widget child = switch (state) {
      DailyTestCardState.loading => _LoadingSlot(color: c.orangeDeep),
      DailyTestCardState.todo => PressableButton(
          key: buttonKey,
          label: buttonLabel,
          onPressed: onPressed,
          tone: ButtonTone.navy,
          height: buttonHeight,
          reserveLip: false,
          trailingIcon: Directionality.of(context) == TextDirection.rtl
              ? Icons.arrow_back_rounded
              : Icons.arrow_forward_rounded,
          pulse: true,
          shine: true,
        ),
      DailyTestCardState.done => PressableButton(
          key: buttonKey,
          label: buttonLabel,
          onPressed: onPressed,
          tone: ButtonTone.orange,
          height: buttonHeight,
          reserveLip: false,
          haptic: ButtonHaptic.light,
          trailingIcon: Directionality.of(context) == TextDirection.rtl
              ? Icons.arrow_back_rounded
              : Icons.arrow_forward_rounded,
        ),
    };
    final loadingToTodo = state != DailyTestCardState.loading;
    return AnimatedSwitcher(
      duration: fade,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: loadingToTodo
            ? SlideTransition(
                position: Tween(begin: const Offset(0, .3), end: Offset.zero)
                    .chain(CurveTween(curve: AppMotion.pop))
                    .animate(animation),
                child: child,
              )
            : child,
      ),
      child: KeyedSubtree(key: ValueKey(state), child: child),
    );
  }
}

/// The header chip: a check and a short label.
class _Chip extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;

  const _Chip({
    required this.label,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 160),
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_rounded, size: 14, color: foreground),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .labelMedium!
                    .withWeight(FontWeight.w800)
                    .copyWith(color: foreground, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The loading state's button slot: three dots and "Getting today's test".
class _LoadingSlot extends StatelessWidget {
  final Color color;
  const _LoadingSlot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: DailyTestCard.buttonHeight,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .6),
        borderRadius: BorderRadius.circular(PressableButton.radius),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Dots(color: color),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              context.l10n.dailyCardLoading,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall!
                  .withWeight(FontWeight.w900)
                  .copyWith(color: color, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dots extends StatefulWidget {
  final Color color;
  const _Dots({required this.color});

  @override
  State<_Dots> createState() => _DotsState();
}

class _DotsState extends State<_Dots> with SingleTickerProviderStateMixin {
  AnimationController? _loop;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.loopsOn(context) && _loop == null) {
      _loop = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 1200))
        ..repeat();
    }
  }

  @override
  void dispose() {
    _loop?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget dot(int i, double t) {
      final p = (t - i * .17) % 1.0;
      final o = p < .4
          ? .2 + .8 * (p / .4)
          : (p < .8 ? 1 - .8 * ((p - .4) / .4) : .2);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.5),
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: o.clamp(.2, 1.0)),
            shape: BoxShape.circle,
          ),
        ),
      );
    }

    final loop = _loop;
    if (loop == null) {
      return Row(
          mainAxisSize: MainAxisSize.min,
          children: [for (var i = 0; i < 3; i++) dot(i, .4)]);
    }
    return AnimatedBuilder(
      animation: loop,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [for (var i = 0; i < 3; i++) dot(i, loop.value)],
      ),
    );
  }
}

/// One line of text that shrinks from its style's size down to [minSize]
/// before it truncates with "…" (X05: the title shrinks to 22).
class _FitTitle extends StatelessWidget {
  final String text;
  final TextStyle style;
  final double minSize;

  const _FitTitle({required this.text, required this.style}) : minSize = 22;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final direction = Directionality.of(context);
      var size = style.fontSize ?? 26;
      while (size > minSize) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style.copyWith(fontSize: size)),
          maxLines: 1,
          textDirection: direction,
          textScaler: TextScaler.noScaling,
        )..layout();
        final fits = painter.width <= constraints.maxWidth;
        painter.dispose();
        if (fits) break;
        size -= 1;
      }
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
        textScaler: TextScaler.noScaling,
        style: style.copyWith(fontSize: size),
      );
    });
  }
}
