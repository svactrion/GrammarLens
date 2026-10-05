import 'package:flutter/material.dart';

/// "GrammarLens" as the app writes it on its screens (Home's title, the
/// onboarding and paywall headers, the launch screen): "Grammar" in the
/// [style]'s colour and "Lens" in brandOrange (`colorScheme.primary`:
/// #FF7A1A light, #FF8A3D dark). Owner decision, 2026-10-05, after the
/// Batch 13 debug trial; every build. One widget so the wordmark is made in
/// one place. Only a colour span: the size, weight, letter spacing and
/// width are the [style]'s, and a screen reader reads one word.
///
/// Not used by Welcome: its light page is the brand orange itself, where an
/// orange "Lens" would vanish (1.00:1), so it keeps a one-colour title.
class BrandWordmark extends StatelessWidget {
  static const String text = 'GrammarLens';

  final TextStyle? style;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final int? maxLines;
  final TextScaler? textScaler;

  const BrandWordmark({
    super.key,
    this.style,
    this.textAlign,
    this.textDirection,
    this.maxLines,
    this.textScaler,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: text,
      textDirection: textDirection,
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
        textDirection: textDirection,
        maxLines: maxLines,
        textScaler: textScaler,
      ),
    );
  }
}
