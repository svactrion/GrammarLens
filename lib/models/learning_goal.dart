/// Why the user is learning English, captured once during onboarding
/// (PRD v2 §4). Feeds topic suggestions later — see the onboarding rationale
/// for why this earns its place while age/occupation don't yet.
enum LearningGoal { examPrep, work, general }

extension LearningGoalInfo on LearningGoal {
  String get label {
    switch (this) {
      case LearningGoal.examPrep:
        return 'Exam prep';
      case LearningGoal.work:
        return 'Work';
      case LearningGoal.general:
        return 'General fluency';
    }
  }

  String get description {
    switch (this) {
      case LearningGoal.examPrep:
        return 'IELTS, TOEFL, or another English exam';
      case LearningGoal.work:
        return 'Emails, meetings, and professional English';
      case LearningGoal.general:
        return 'Everyday confidence, no specific goal';
    }
  }

  static LearningGoal fromJson(String? value) {
    switch (value) {
      case 'exam_prep':
        return LearningGoal.examPrep;
      case 'work':
        return LearningGoal.work;
      case 'general':
      default:
        return LearningGoal.general;
    }
  }

  String toJson() {
    switch (this) {
      case LearningGoal.examPrep:
        return 'exam_prep';
      case LearningGoal.work:
        return 'work';
      case LearningGoal.general:
        return 'general';
    }
  }
}
