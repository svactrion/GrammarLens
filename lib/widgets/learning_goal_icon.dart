import 'package:flutter/material.dart';

import '../models/learning_goal.dart';

/// Each goal's icon: the goal card (V05) and the "Your climb" chip on
/// getting ready (V05b) show the same one.
IconData learningGoalIcon(LearningGoal goal) => switch (goal) {
      LearningGoal.examPrep => Icons.school_outlined,
      LearningGoal.work => Icons.work_outline_rounded,
      LearningGoal.school => Icons.menu_book_rounded,
      LearningGoal.general => Icons.chat_bubble_outline_rounded,
    };
