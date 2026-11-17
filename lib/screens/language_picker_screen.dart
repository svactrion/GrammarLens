import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../app_colors.dart';
import '../motion.dart';
import '../theme.dart';
import '../utils/haptics.dart';
import '../widgets/pressable_button.dart';
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
        // R07: each language its own card in its own name; the selected
        // one a navy card with a check.
        for (final language in options) ...[
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
              HapticMap.selection();
              onSelected(language);
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(height: 10),
        ],
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
    final c = AppColors.of(context);
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: PressableCard(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.orInstant(context, AppMotion.fast),
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 12),
          decoration: lipCard(c,
              color: selected ? c.navy : c.card,
              border: selected ? c.navy : c.line,
              lip: selected ? c.navyDeep : c.lip,
              radius: 18),
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
                          ?.withWeight(FontWeight.w800)
                          .copyWith(color: selected ? c.onNavy : c.text),
                    ),
                    if (detail != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        detail!,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: selected ? c.onNavyMuted : c.muted),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ExcludeSemantics(
                child: AnimatedScale(
                  scale: selected ? 1 : .85,
                  duration: AppMotion.orInstant(context, AppMotion.fast),
                  curve: AppMotion.pop,
                  child: Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 22,
                    color: selected ? c.gold : c.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
