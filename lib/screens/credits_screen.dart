import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
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

  // The work, its author and its licence are names: never translated.
  static const String avatarWork = 'Cute Animal 3D Icons'; // l10n-guard: a name
  static const String avatarAuthor = 'Tran Mau Tri Tam'; // l10n-guard: a name
  static const String avatarLicense = 'CC BY 4.0'; // l10n-guard: a name

  /// The attribution, as the screen says it.
  static String avatarAttribution(AppLocalizations l10n) =>
      l10n.creditsAvatarAttribution(avatarWork, avatarAuthor, avatarLicense);

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
        PageHeader(
            title: context.l10n.creditsTitle,
            subtitle: context.l10n.creditsSubtitle),
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
                        context.l10n.creditsAvatarHeading,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(color: scheme.onSurface),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text.rich(
                      TextSpan(
                          children: emphasizedSpans(
                        avatarAttribution(context.l10n),
                        emphasized: const [
                          avatarWork,
                          avatarAuthor,
                          avatarLicense
                        ],
                        style: strong,
                      )),
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant, height: 1.6),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: scheme.outlineVariant),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 19),
                child: LegalLinkRow(
                    label: context.l10n.creditsFigmaLink,
                    url: AppLinks.avatarSetUrl),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 19),
                child: Divider(height: 1, color: scheme.outlineVariant),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 19),
                child: LegalLinkRow(
                    label: context.l10n.creditsLicenseLink(avatarLicense),
                    url: AppLinks.ccBy4Url),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
