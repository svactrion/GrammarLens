import 'package:flutter/material.dart';

import '../models/medal_tier.dart';

/// Each tier's metal color, shared by the medal collection and the Home
/// score bar so a tier looks the same wherever it appears.
extension MedalTierColor on MedalTier {
  Color get color => switch (this) {
        MedalTier.bronze => const Color(0xFFB56A3B),
        MedalTier.silver => const Color(0xFF8A95A3),
        MedalTier.gold => const Color(0xFFD39B21),
      };
}
