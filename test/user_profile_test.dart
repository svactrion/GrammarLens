import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/learning_goal.dart';
import 'package:grammar_lens/models/user_profile.dart';

/// This batch's migration guarantee, at the actual point storage reads
/// hit it: a profile row saved under the previous avatar id scheme (or
/// any other unrecognized string) must load without throwing, falling
/// back to no avatar rather than crashing the app on launch.
void main() {
  test(
      'UserProfile.fromMap falls back to no avatar for an unrecognized id, '
      'never throws', () {
    final map = {
      'name': 'Ada',
      'learning_goal': LearningGoal.work.toJson(),
      'avatar': 'fox', // previous, now-replaced avatar set's id
    };

    final profile = UserProfile.fromMap(map);

    expect(profile.avatar, isNull);
    expect(profile.name, 'Ada');
  });

  test('UserProfile.fromMap round-trips a current-set avatar id', () {
    final avatar = Avatar.values.first;
    final map = {
      'name': 'Ada',
      'learning_goal': LearningGoal.work.toJson(),
      'avatar': avatar.toJson(),
    };

    expect(UserProfile.fromMap(map).avatar, avatar);
  });

  test('toMap -> fromMap round-trips an avatar unchanged', () {
    const profile = UserProfile(name: 'Ada', learningGoal: LearningGoal.work);
    final withAvatar = profile.copyWith(avatar: Avatar.values[5]);

    final restored = UserProfile.fromMap(withAvatar.toMap());

    expect(restored.avatar, Avatar.values[5]);
  });

  test(
      'the stored profile carries only name, goal and avatar — no age or '
      'occupation', () {
    const profile = UserProfile(name: 'Ada', learningGoal: LearningGoal.work);

    expect(profile.toMap().keys.toSet(),
        {'id', 'name', 'learning_goal', 'avatar'});
  });
}
