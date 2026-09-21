import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/app_messenger.dart';

/// A small text link to a legal or attribution page, disabled (greyed out, non-
/// interactive) rather than shown as live and then failing silently or
/// erroring, whenever [url] is still the empty placeholder from
/// app_links.dart — see that file's doc comment. Once a real URL is set
/// (as of the custom-domain batch, both are), tapping opens it in the
/// system browser via `url_launcher`.
class LegalLink extends StatelessWidget {
  final String label;
  final String url;

  const LegalLink({super.key, required this.label, required this.url});

  Future<void> _open() async {
    final uri = Uri.parse(url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      AppMessenger.show('Could not open $label.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      // Explicit color for the same reason the Premium screen's Restore
      // Purchases button needs one: an unstyled TextButton takes
      // colorScheme.primary, which is the page's own orange in light mode.
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.secondary,
      ),
      onPressed: url.isEmpty ? null : _open,
      child: Text(label),
    );
  }
}
