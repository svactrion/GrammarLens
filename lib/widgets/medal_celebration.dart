import 'package:flutter/material.dart';

import 'confetti_burst.dart';

/// The medal celebration (Batch 5, N15): a layer over the Daily Test
/// result screen, opened the moment the test is saved, for a tier just
/// secured or the Welcome badge. The medal and the confetti come at the
/// opening; one tap anywhere closes it and the results show. Under Reduce
/// Motion: no confetti and no fade.
///
/// It replaces the Welcome card under the results, which sat 980–1954 pt
/// below the fold on every screen (Batch 5 Batch 0 §2), so the celebration
/// was in practice never seen.
class MedalCelebration extends StatefulWidget {
  /// The medal (`MedalBadge`, a [disc]-point disc).
  final Widget medal;
  final String title;
  final String subtitle;
  final VoidCallback onClose;

  const MedalCelebration({
    super.key,
    required this.medal,
    required this.title,
    required this.subtitle,
    required this.onClose,
  });

  /// The medal's disc in the layer: its canvas is 126 pt, under the 128 pt
  /// above which the 384 px assets would be soft (N23).
  static const disc = 112.0;

  static const closeHint = 'Tap to continue';

  static const fadeIn = Duration(milliseconds: 200);

  @override
  State<MedalCelebration> createState() => _MedalCelebrationState();
}

class _MedalCelebrationState extends State<MedalCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade =
      AnimationController(vsync: this, duration: MedalCelebration.fadeIn);
  final _medalKey = GlobalKey();
  Offset? _confettiFrom;
  bool _closed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _fade.value = 1;
    } else if (!_fade.isAnimating && _fade.value == 0) {
      _fade.forward();
      // The confetti from the medal's centre, once it is laid out.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final box = _medalKey.currentContext?.findRenderObject();
        final layer = context.findRenderObject();
        if (box is! RenderBox || layer is! RenderBox || !box.hasSize) return;
        setState(() => _confettiFrom = layer
            .globalToLocal(box.localToGlobal(box.size.center(Offset.zero))));
      });
    }
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  void _close() {
    if (_closed) return;
    _closed = true;
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onContainer = scheme.onSecondaryContainer;
    final from = _confettiFrom;
    return FadeTransition(
      opacity: _fade,
      child: Semantics(
        container: true,
        liveRegion: true,
        button: true,
        label: '${widget.title}. ${widget.subtitle}. '
            '${MedalCelebration.closeHint}.',
        onTap: _close,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _close,
          child: Material(
            color: scheme.scrim.withValues(alpha: .55),
            child: Stack(children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    // The same width for every celebration, whatever its
                    // copy.
                    child: SizedBox(
                      width: double.infinity,
                      child: Card(
                        color: scheme.secondaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              KeyedSubtree(key: _medalKey, child: widget.medal),
                              const SizedBox(height: 16),
                              Text(
                                widget.title,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: onContainer,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                widget.subtitle,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(color: onContainer),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                MedalCelebration.closeHint,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: onContainer.withValues(alpha: .75),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (from != null)
                ConfettiBurst(
                  origin: from,
                  colors: [scheme.primary, scheme.secondary, scheme.tertiary],
                ),
            ]),
          ),
        ),
      ),
    );
  }
}
