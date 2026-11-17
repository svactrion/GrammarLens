/// Why the user is learning English, asked once during onboarding (PRD v2
/// §4). It personalizes nothing: it is asked to understand who uses the app
/// and what to improve next (the 1.2.0 additional screens package), and it
/// is reported as the `learning_goal` analytics user property
/// (docs/analytics-plan.md §3). Optional: a skipped goal is stored as
/// [learningGoalSkipped] and read back as null, never as [general].
/// In the order V05 lists them (fix round 2 added [school], SPEC §1.14).
enum LearningGoal { examPrep, work, school, general }

/// The stored and reported value of a skipped goal: a fourth value in the
/// `learning_goal` column (no schema change). Builds before 1.2.0 read it,
/// like any unknown value, as [LearningGoal.general]; builds before fix
/// round 2 read `school` the same way.
const String learningGoalSkipped = 'skipped';

extension LearningGoalInfo on LearningGoal {
  static LearningGoal fromJson(String? value) {
    switch (value) {
      case 'exam_prep':
        return LearningGoal.examPrep;
      case 'work':
        return LearningGoal.work;
      case 'school':
        return LearningGoal.school;
      case 'general':
      default:
        return LearningGoal.general;
    }
  }

  /// The goal as stored, or null for [learningGoalSkipped]. Anything else
  /// unknown (or a missing value) keeps [fromJson]'s `general`.
  static LearningGoal? fromStored(String? value) =>
      value == learningGoalSkipped ? null : fromJson(value);

  String toJson() {
    switch (this) {
      case LearningGoal.examPrep:
        return 'exam_prep';
      case LearningGoal.work:
        return 'work';
      case LearningGoal.school:
        return 'school';
      case LearningGoal.general:
        return 'general';
    }
  }
}

/// The stored and reported value of an optional goal: its own value, or
/// [learningGoalSkipped].
String learningGoalValue(LearningGoal? goal) =>
    goal?.toJson() ?? learningGoalSkipped;
