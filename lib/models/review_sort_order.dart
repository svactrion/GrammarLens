/// How the Review list orders weak spots. Defaults to [recent] — a mistake
/// made yesterday is more actionable than one made ten times three weeks
/// ago (PRD §2.1).
enum ReviewSortOrder { recent, frequent }

extension ReviewSortOrderJson on ReviewSortOrder {
  static ReviewSortOrder fromJson(String? value) {
    switch (value) {
      case 'frequent':
        return ReviewSortOrder.frequent;
      case 'recent':
      default:
        return ReviewSortOrder.recent;
    }
  }

  String toJson() {
    switch (this) {
      case ReviewSortOrder.recent:
        return 'recent';
      case ReviewSortOrder.frequent:
        return 'frequent';
    }
  }

  String get label {
    switch (this) {
      case ReviewSortOrder.recent:
        return 'Recent';
      case ReviewSortOrder.frequent:
        return 'Most frequent';
    }
  }
}
