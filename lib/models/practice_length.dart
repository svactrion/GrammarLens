/// How many questions a generated practice set contains. This is a length
/// choice, not a difficulty choice — the questions themselves are generated
/// at the same difficulty regardless, only the count changes. Defaults to
/// [standard] the first time a user practices; after that the storage layer
/// remembers whichever option was picked last (see
/// `StorageService.getPracticeLength`).
enum PracticeLength { quick, standard, extended }

extension PracticeLengthInfo on PracticeLength {
  int get questionCount {
    switch (this) {
      case PracticeLength.quick:
        return 3;
      case PracticeLength.standard:
        return 5;
      case PracticeLength.extended:
        return 10;
    }
  }

  String get label {
    switch (this) {
      case PracticeLength.quick:
        return 'Quick';
      case PracticeLength.standard:
        return 'Standard';
      case PracticeLength.extended:
        return 'Extended';
    }
  }

  String get description {
    switch (this) {
      case PracticeLength.quick:
        return 'A short warm-up';
      case PracticeLength.standard:
        return 'The balanced session';
      case PracticeLength.extended:
        return 'A deep, thorough workout';
    }
  }

  static PracticeLength fromQuestionCount(int? value) {
    switch (value) {
      case 3:
        return PracticeLength.quick;
      case 10:
        return PracticeLength.extended;
      case 5:
      default:
        return PracticeLength.standard;
    }
  }
}
