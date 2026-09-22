import 'avatar.dart';
import 'learning_goal.dart';

/// The guest-first user identity (PRD v2 §5 — no accounts, no backend).
/// Existence of a saved profile is what onboarding-complete means: there is
/// no separate flag, since a guest install either has one or doesn't.
class UserProfile {
  final String name;
  final LearningGoal learningGoal;
  final Avatar? avatar;

  const UserProfile({
    required this.name,
    required this.learningGoal,
    this.avatar,
  });

  UserProfile copyWith({
    String? name,
    LearningGoal? learningGoal,
    // No clearAvatar flag: nothing in the app ever clears an avatar back to
    // null — the carousel picker (avatar_carousel.dart) always has some
    // avatar centered, never an empty state, so there's no "remove" gesture
    // to plumb through here. A stored profile can still have a null avatar
    // (a legacy install from before onboarding started assigning one, or an
    // id `Avatar.fromJson` didn't recognize), but nothing in the UI ever
    // asks to set it back to null on purpose.
    Avatar? avatar,
  }) {
    return UserProfile(
      name: name ?? this.name,
      learningGoal: learningGoal ?? this.learningGoal,
      avatar: avatar ?? this.avatar,
    );
  }

  Map<String, Object?> toMap() => {
        'id': 0,
        'name': name,
        'learning_goal': learningGoal.toJson(),
        'avatar': avatar?.toJson(),
      };

  factory UserProfile.fromMap(Map<String, Object?> map) => UserProfile(
        name: map['name'] as String,
        learningGoal:
            LearningGoalInfo.fromJson(map['learning_goal'] as String?),
        avatar: Avatar.fromJson(map['avatar'] as String?),
      );
}
