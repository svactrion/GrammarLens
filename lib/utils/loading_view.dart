import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/brand_scaffold.dart';
import 'content_width.dart';

/// Full-screen, clearly-visible loading state shown while a practice set is
/// generating or while submitted answers are being evaluated.
///
/// A bare `CircularProgressIndicator` used to stand in for this, but its
/// default color is `colorScheme.primary` — which is also the scaffold
/// background color in light mode — so it rendered invisibly on top of
/// itself and read as a frozen/blank screen. This centers a large, animated
/// send/paper-airplane icon (gently floating and tilting, like it's
/// actively "sending" or "being reviewed") in the blue accent color, which
/// always contrasts with the page behind it.
///
/// Deliberately does not paint its own background (an earlier version did,
/// with `theme.scaffoldBackgroundColor`) — every `Scaffold` this sits
/// inside, migrated onto `BrandScaffold` or not, already paints its own
/// `backgroundColor` behind `body` on its own, so a second explicit fill
/// here was always redundant on the old full-band scaffold and became
/// actively wrong once `BrandScaffold` gives its `Scaffold` a different
/// (neutral) background than the ambient theme default: painting
/// `scaffoldBackgroundColor` again here would have silently repainted the
/// old band color under this view, undoing the neutral body it's sitting
/// on. Relying on the host's own fill instead means this widget is correct
/// in both contexts with no special-casing.
class LoadingView extends StatefulWidget {
  final String message;

  const LoadingView({super.key, required this.message});

  @override
  State<LoadingView> createState() => _LoadingViewState();
}

class _LoadingViewState extends State<LoadingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground =
        theme.appBarTheme.foregroundColor ?? theme.colorScheme.onSurface;
    return SizedBox.expand(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final t = Curves.easeInOut.transform(_controller.value);
                  return Transform.translate(
                    offset: Offset(0, -12 * t),
                    child: Transform.rotate(
                      angle: (t - 0.5) * 0.3,
                      child: child,
                    ),
                  );
                },
                child: Icon(
                  Icons.send_rounded,
                  size: 64,
                  color: theme.colorScheme.secondary,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                widget.message,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium
                    ?.withWeight(FontWeight.w800)
                    .copyWith(color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A page's loading state with the page's own header kept in place (final
/// screens A3): [header] at the top of the page, as the loaded page draws
/// it, and [LoadingView] under it. Replaces a centred app bar title that
/// the loaded page does not have, so nothing jumps when it arrives.
class PageLoading extends StatelessWidget {
  /// The status bar only, for a page whose back button is in the page
  /// (Topic Practice); null for `BrandScaffold`'s own app bar with just its
  /// back button (the weak spot detail).
  final PreferredSizeWidget? appBar;
  final Widget header;
  final String message;

  const PageLoading({
    super.key,
    this.appBar,
    required this.header,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final hPad = ContentWidth.sidePaddingOf(context);
    return BrandScaffold(
      appBar: appBar,
      title: appBar == null ? const SizedBox.shrink() : null,
      body: Padding(
        padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            Expanded(child: LoadingView(message: message)),
          ],
        ),
      ),
    );
  }
}
