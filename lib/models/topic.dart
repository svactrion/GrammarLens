import 'package:flutter/material.dart';

enum TopicId {
  gerundVsInfinitive,
  modalVerbs,
  modalPastForms,
  tenseSelection,
  articles,
}

/// A grammar topic. Its title and description are interface text, in the
/// strings (`topic.title(l10n)`, `lib/l10n/labels.dart`; 1.4.0 B4.4).
class Topic {
  final TopicId id;
  final IconData icon;

  const Topic({
    required this.id,
    required this.icon,
  });
}
