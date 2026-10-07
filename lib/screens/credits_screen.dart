import 'package:flutter/material.dart';

import '../theme.dart';
import '../utils/app_links.dart';
import '../widgets/brand_scaffold.dart';
import '../widgets/legal_link.dart';
import '../widgets/page_header.dart';

/// Profile → Credits. Attribution required by the avatar set's CC BY 4.0
/// licence: the work, its author, where it comes from, that it was adapted
/// and the licence, with the source and the licence as two links (1.2.0
/// final screens, brief §4: one plain card as tall as its content, no
/// artwork, no raw URLs in the text). The links open the way the Premium
/// screen's legal links do ([openLegalLink]).
class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key});

  static const cardKey = ValueKey('credits_card');

  /// The attribution, as the screen says it.
  static const String avatarAttribution =
      'Adapted from Cute Animal 3D Icons by Tran Mau Tri Tam, via Figma '
      'Community. Licensed under CC BY 4.0.';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final strong =
        TextStyle(color: scheme.onSurface).withWeight(FontWeight.w700);
    final hPad = MediaQuery.sizeOf(context).width < 360 ? 16.0 : 20.0;

    return BrandScaffold(
      // The status bar's height only: the header is in the page.
      appBar: AppBar(
        toolbarHeight: 0,
        automaticallyImplyLeading: false,
        scrolledUnderElevation: 0,
      ),
      horizontalPadding: hPad,
      children: [
        const PageHeader(
            title: 'Credits', subtitle: 'Artwork and attribution.'),
        const SizedBox(height: 24),
        Card(
          key: cardKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(19, 21, 19, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        'Avatar illustrations',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(color: scheme.onSurface),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text.rich(
                      TextSpan(children: [
                        const TextSpan(text: 'Adapted from '),
                        TextSpan(text: 'Cute Animal 3D Icons', style: strong),
                        const TextSpan(text: ' by '),
                        TextSpan(text: 'Tran Mau Tri Tam', style: strong),
                        const TextSpan(
                            text: ', via Figma Community. Licensed under '),
                        TextSpan(text: 'CC BY 4.0', style: strong),
                        const TextSpan(text: '.'),
                      ]),
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant, height: 1.6),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: scheme.outlineVariant),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 19),
                child: LegalLinkRow(
                    label: 'Figma file', url: AppLinks.avatarSetUrl),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 19),
                child: Divider(height: 1, color: scheme.outlineVariant),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 19),
                child: LegalLinkRow(
                    label: 'CC BY 4.0 license', url: AppLinks.ccBy4Url),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
