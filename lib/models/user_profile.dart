import 'avatar.dart';
import 'learning_goal.dart';

/// The guest-first user identity (PRD v2 §5 — no accounts, no backend).
/// Existence of a saved profile is what onboarding-complete means: there is
/// no separate flag, since a guest install either has one or doesn't.
class UserProfile {
  final String name;
  final LearningGoal learningGoal;
  final int? age;
  final String? occupation;
  final Avatar? avatar;

  const UserProfile({
    required this.name,
    required this.learningGoal,
    this.age,
    this.occupation,
    this.avatar,
  });

  UserProfile copyWith({
    String? name,
    LearningGoal? learningGoal,
    // Nullable fields need an explicit "clear" flag — passing null through
    // `age ?? this.age` could never actually clear a previously-set value.
    int? age,
    bool clearAge = false,
    String? occupation,
    bool clearOccupation = false,
    // No clearAvatar flag: unlike age/occupation, nothing in the app ever
    // clears an avatar back to null any more — the carousel picker
    // (avatar_carousel.dart) always has some avatar centered, never an
    // empty state, so there's no "remove" gesture left to plumb through
    // here. A stored profile can still have a null avatar (a legacy
    // install from before onboarding started assigning one, or an id
    // `Avatar.fromJson` didn't recognize), but nothing in the UI ever
    // asks to set it back to null on purpose.
    Avatar? avatar,
  }) {
    return UserProfile(
      name: name ?? this.name,
      learningGoal: learningGoal ?? this.learningGoal,
      age: clearAge ? null : (age ?? this.age),
      occupation: clearOccupation ? null : (occupation ?? this.occupation),
      avatar: avatar ?? this.avatar,
    );
  }

  Map<String, Object?> toMap() => {
        'id': 0,
        'name': name,
        'learning_goal': learningGoal.toJson(),
        'age': age,
        'occupation': occupation,
        'avatar': avatar?.toJson(),
      };

  factory UserProfile.fromMap(Map<String, Object?> map) => UserProfile(
        name: map['name'] as String,
        learningGoal:
            LearningGoalInfo.fromJson(map['learning_goal'] as String?),
        age: map['age'] as int?,
        occupation: map['occupation'] as String?,
        avatar: Avatar.fromJson(map['avatar'] as String?),
      );
}
