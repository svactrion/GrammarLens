/// Welcome's "Watch" demo (V02): a learner's sentence with a mistake, its
/// correction and the rule. English content, like the questions and the
/// feedback: the same in every interface language (1.4.0 D2), shown inside
/// `EnglishContent`.
// l10n-guard-begin: English content, the same in every language (1.4.0 D2)
abstract final class WelcomeDemo {
  static const wrongBefore = 'She ';
  static const wrongWord = 'don’t';
  static const wrongAfter = ' like coffee.';
  static const rightBefore = 'She ';
  static const rightWord = 'doesn’t';
  static const rightAfter = ' like coffee.';
  static const rule = 'She / he / it → does not.';

  static const wrong = '$wrongBefore$wrongWord$wrongAfter';
  static const right = '$rightBefore$rightWord$rightAfter';
}
// l10n-guard-end
