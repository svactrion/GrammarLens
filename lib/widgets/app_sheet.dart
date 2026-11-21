import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../motion.dart';

/// The app's bottom sheet (SPEC §3.6: RV06, PF04, PF03, P08): springs in
/// from the bottom in 450 ms, card colour, radius 28 at the top, a grabber;
/// swipe down or tap outside to close. Reduce Motion: a short fade-length
/// slide.
///
/// Fix round 7, item 2: the sheet's surface and grabber read their colours
/// in the sheet's own build, so they follow an appearance change while the
/// sheet is open (the route's background colour is fixed for its life, so
/// it stays transparent and the shape clips the surface). The barrier's
/// scrim is still the one of the appearance the sheet opened in.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool showGrabber = true,
}) {
  final scrim = AppColors.of(context).scrim;
  final reduced = AppMotion.reduced(context);
  const shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  );
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: scrim,
    showDragHandle: false,
    shape: shape,
    clipBehavior: Clip.antiAlias,
    sheetAnimationStyle: AnimationStyle(
      duration: reduced ? AppMotion.fast : AppMotion.sheet,
      reverseDuration: reduced ? AppMotion.fast : AppMotion.base,
      curve: AppMotion.spring,
      reverseCurve: AppMotion.exit,
    ),
    builder: (context) {
      final c = AppColors.of(context);
      // The surface: a Material, so ink inside the sheet paints on it.
      return Material(
        color: c.card,
        child: Padding(
          // Rises with the keyboard (PF04).
          padding:
              EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showGrabber)
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: c.line,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              Flexible(child: builder(context)),
            ],
          ),
        ),
      );
    },
  );
}
