import 'package:flutter/material.dart';

import '../utils/app_links.dart';
import '../utils/page_title.dart';
import '../widgets/brand_scaffold.dart';
import '../widgets/legal_link.dart';

/// Profile → Credits. Attribution required by the avatar set's CC BY 4.0
/// licence. A screen rather than a dialog: the text is long, carries two URLs
/// and must stay readable at the largest text size. The links open the same
/// way the Premium screen's legal links do ([LegalLink]).
class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key});

  /// The attribution sentence as the licence requires it, URLs included.
  static const String avatarAttribution =
      'Avatar illustrations adapted from "Cute Animal 3D Icons" by Tran Mau '
      'Tri Tam, via Figma Community (${AppLinks.avatarSetUrl}), licensed '
      'under CC BY 4.0 (${AppLinks.ccBy4Url}).';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BrandScaffold(
      title: const PageTitle('Credits'),
      children: [
        Text(avatarAttribution, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),
        const Wrap(
          children: [
            LegalLink(label: 'Figma file', url: AppLinks.avatarSetUrl),
            LegalLink(label: 'CC BY 4.0 license', url: AppLinks.ccBy4Url),
          ],
        ),
      ],
    );
  }
}
