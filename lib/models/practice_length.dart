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
