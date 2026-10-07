import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';
import '../utils/app_messenger.dart';

/// Opens [url] in the system browser; says so briefly when it cannot
/// ("Could not open [label].") and leaves the screen as it is.
Future<void> openLegalLink({required String label, required String url}) async {
  bool launched;
  try {
    launched =
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {
    launched = false;
  }
  if (!launched) AppMessenger.show('Could not open $label.');
}

/// A small text link to a legal or attribution page, disabled (greyed out, non-
/// interactive) rather than shown as live and then failing silently or
/// erroring, whenever [url] is still the empty placeholder from
/// app_links.dart — see that file's doc comment. Once a real URL is set
/// (as of the custom-domain batch, both are), tapping opens it in the
/// system browser via `url_launcher`.
class LegalLink extends StatelessWidget {
  final String label;
  final String url;

  /// No side padding, so the label starts at the text edge above it (a link
  /// under a paragraph, final screens A3); the target stays at least 44 pt
  /// tall and wide.
  final bool flush;

  const LegalLink(
      {super.key, required this.label, required this.url, this.flush = false});

  Future<void> _open() => openLegalLink(label: label, url: url);

  @override
  Widget build(BuildContext context) {
    return TextButton(
      // Explicit color for the same reason the Premium screen's Restore
      // Purchases button needs one: an unstyled TextButton takes
      // colorScheme.primary, which is the page's own orange in light mode.
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.secondary,
        padding: flush ? EdgeInsets.zero : null,
        minimumSize: flush ? const Size(44, 44) : null,
        tapTargetSize: flush ? MaterialTapTargetSize.shrinkWrap : null,
      ),
      onPressed: url.isEmpty ? null : _open,
      child: Text(label),
    );
  }
}

/// A full-width link row inside a card (Credits, 1.2.0 final screens): the
/// label in the link colour and an "opens outside the app" icon, at least
/// 55 pt tall. Opens like [LegalLink].
class LegalLinkRow extends StatelessWidget {
  final String label;
  final String url;

  const LegalLinkRow({super.key, required this.label, required this.url});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.secondary;
    return Semantics(
      link: true,
      child: InkWell(
        onTap: url.isEmpty ? null : () => openLegalLink(label: label, url: url),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 55),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium
                      ?.withWeight(FontWeight.w800)
                      .copyWith(color: color),
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.open_in_new_rounded, size: 17, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
