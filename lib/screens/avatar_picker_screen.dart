import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/avatar.dart';
import '../widgets/buddy_picker.dart';
import 'lucky_wheel_screen.dart';

/// Shared between this screen's centered avatar and Settings' own small
/// preview row (`settings_screen.dart`), for the Settings → picker → back
/// flight.
const String avatarHeroTag = 'profile-avatar';

/// The tag Home's avatar used before the UI polish removed it from Home
/// (V14); kept only for the v1.2.0 hero measurement script in
/// `tool/design_measure/v120`.
const String homeAvatarHeroTag = 'home-avatar';

/// Change your buddy (R06): the onboarding turntable ([BuddyPicker]) opened
/// from Profile or Home, titled "Change your buddy" / "Your progress stays
/// the same". "Save <Hero>" saves and closes; "Try my luck" opens the wheel
/// (V03b) whose primary button also reads "Save <Hero>". Progress never
/// changes. Leaving without saving keeps the buddy as it was.
class AvatarPickerScreen extends StatelessWidget {
  final Avatar currentAvatar;
  final ValueChanged<Avatar> onAvatarChanged;

  const AvatarPickerScreen({
    super.key,
    required this.currentAvatar,
    required this.onAvatarChanged,
  });

  static const backKey = ValueKey('avatar_picker_back');

  void _save(BuildContext context, Avatar hero) {
    if (hero != currentAvatar) onAvatarChanged(hero);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    String label(Avatar hero) => l10n.buddySave(hero.name(l10n));
    return Scaffold(
      body: BuddyPicker(
        initial: currentAvatar,
        title: l10n.buddyChangeTitle,
        subtitle: l10n.buddyChangeSubtitle,
        primaryLabel: label,
        onConfirm: (hero) => _save(context, hero),
        onTryLuck: (front) async {
          final result = await openLuckyWheel(context,
              current: front, primaryLabel: label);
          if (result == null || !context.mounted) return null;
          if (result.confirmed) {
            _save(context, result.hero);
            return null;
          }
          return result.hero;
        },
        leading: IconButton(
          key: backKey,
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => Navigator.of(context).maybePop(),
          icon: Icon(Directionality.of(context) == TextDirection.rtl
              ? Icons.chevron_right_rounded
              : Icons.chevron_left_rounded),
        ),
      ),
    );
  }
}
