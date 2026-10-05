import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../utils/debug_tools.dart';

/// A trial (owner, 2026-10-05): the debug panel's "Two-colour wordmark".
/// While on, every in-app "GrammarLens" drawn by [BrandWordmark] shows
/// "Grammar" in its usual colour and "Lens" in brandOrange
/// (`colorScheme.primary`: #FF7A1A light, #FF8A3D dark). Memory only (off at
/// every launch); debug and profile builds only, like the panel itself: in a
/// release build [kReleaseMode] is the constant true, so [enabled] is
/// always false there and the wordmark is one colour.
abstract final class DebugTwoColourWordmark {
  /// The panel's switch. A notifier, so every wordmark on screen changes at
  /// once, with no restart.
  static final ValueNotifier<bool> runtime = ValueNotifier(false);

  static bool get enabled =>
      !kReleaseMode && DebugTools.enabledForTesting && runtime.value;
}

/// "GrammarLens" as the app writes it on its screens (Home's title, the
/// onboarding and paywall headers). One widget so a change of colour is
/// made once. Only the colour of "Lens" changes with
/// [DebugTwoColourWordmark]: the size, weight, letter spacing and width are
/// the [style]'s either way, and a screen reader reads one word. Not used
/// by the launch screen (its own fixed design) or Welcome (an orange page in
/// light mode, where an orange "Lens" would vanish).
class BrandWordmark extends StatelessWidget {
  static const String text = 'GrammarLens';

  final TextStyle? style;
  final TextAlign? textAlign;

  const BrandWordmark({super.key, this.style, this.textAlign});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: DebugTwoColourWordmark.runtime,
      builder: (context, _, __) {
        if (!DebugTwoColourWordmark.enabled) {
          return Text(text, style: style, textAlign: textAlign);
        }
        return Semantics(
          label: text,
          excludeSemantics: true,
          child: Text.rich(
            TextSpan(children: [
              const TextSpan(text: 'Grammar'),
              TextSpan(
                text: 'Lens',
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ]),
            style: style,
            textAlign: textAlign,
          ),
        );
      },
    );
  }
}
