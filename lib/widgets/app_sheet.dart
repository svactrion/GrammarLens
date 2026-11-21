import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../motion.dart';

/// The app's bottom sheet (SPEC §3.6: RV06, PF04, PF03, P08): springs in
/// from the bottom in 450 ms, card colour, radius 28 at the top, a grabber;
/// swipe down or tap outside to close. Reduce Motion: a short fade-length
/// slide.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool showGrabber = true,
}) {
  final c = AppColors.of(context);
  final reduced = AppMotion.reduced(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: true,
    backgroundColor: c.card,
    barrierColor: c.scrim,
    showDragHandle: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    sheetAnimationStyle: AnimationStyle(
      duration: reduced ? AppMotion.fast : AppMotion.sheet,
      reverseDuration: reduced ? AppMotion.fast : AppMotion.base,
      curve: AppMotion.spring,
      reverseCurve: AppMotion.exit,
    ),
    builder: (context) => Padding(
      // Rises with the keyboard (PF04).
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
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
}
