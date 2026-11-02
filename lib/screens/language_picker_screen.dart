import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../widgets/brand_scaffold.dart';
import '../widgets/page_header.dart';

/// Profile → Appearance → Language (1.4.0 B3; docs/1.4.0-b3-batch0-report.md
/// §2.4, §8 Q3): "System default" first, with the language the device
/// resolves to under it, then each language this build has strings for,
/// under its own name. A tap applies the choice at once and goes back.
///
/// Until the translations land (B5) the list is System default and
/// English; each ARB file added makes its language appear
/// ([AppLanguage.available]).
class LanguagePickerScreen extends StatelessWidget {
  final AppLanguage current;
  final ValueChanged<AppLanguage> onSelected;

  /// The choices offered; [AppLanguage.available] by default. Tests pass a
  /// longer list to see the eight languages before their strings exist.
  final List<AppLanguage>? choices;

  const LanguagePickerScreen({
    super.key,
    required this.current,
    required this.onSelected,
    this.choices,
  });

  static ValueKey<String> optionKey(AppLanguage language) =>
      ValueKey('language_option_${language.name}');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final hPad = MediaQuery.sizeOf(context).width < 360 ? 16.0 : 20.0;
    final options = choices ?? AppLanguage.available();
    final resolved = AppLanguage.forLocale(
        resolveAppLocale(WidgetsBinding.instance.platformDispatcher.locales));

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
          title: l10n.languagePickerTitle,
          subtitle: l10n.languagePickerSubtitle,
        ),
        const SizedBox(height: 24),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final (i, language) in options.indexed) ...[
                if (i > 0)
                  Divider(
                      height: 1, thickness: 1, color: scheme.outlineVariant),
                _Option(
                  key: optionKey(language),
                  title: language == AppLanguage.system
                      ? l10n.settingsLanguageSystemDefault
                      : language.endonym,
                  detail: language == AppLanguage.system
                      ? l10n.languagePickerSystemDetail(resolved.endonym)
                      : null,
                  selected: language == current,
                  onTap: () {
                    onSelected(language);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Option extends StatelessWidget {
  final String title;
  final String? detail;
  final bool selected;
  final VoidCallback onTap;

  const _Option({
    super.key,
    required this.title,
    required this.detail,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.labelLarge
                            ?.copyWith(color: scheme.onSurface),
                      ),
                      if (detail != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          detail!,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ExcludeSemantics(
                  child: Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 20,
                    color:
                        selected ? scheme.secondary : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
