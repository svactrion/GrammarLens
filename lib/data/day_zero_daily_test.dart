import '../models/daily_test_question.dart';
import '../models/practice_item.dart';

/// The first-launch Daily Test (PRD v2 §12.3): the same five questions for
/// every new user, written by hand and shipped inside the app instead of
/// generated. A new user sees the test at once, offline and free of
/// generation cost, and the answer key was read by a person: the first thing a
/// new user does is not left to a model's judgment.
///
/// One question per topic, three fill-in-the-blank and two error-correction,
/// easy to mid difficulty. Each question carries a one-sentence explanation of
/// why its answer is right (shown on every card that has no more specific
/// comment), each predicted wrong answer carries the comment the result
/// screen shows for it, and an error-correction question also has the
/// "unchanged sentence" wrong answer, since copying the sentence back is the
/// most likely wrong attempt.
///
/// A Dart constant rather than an asset: nothing to load, nothing that can be
/// missing, and the tests read it like any other code. The ids are `day0_1` to
/// `day0_5`; they are never generated ones, so they cannot collide with a
/// generated set's `q…` ids in the answers stored for a day.
final List<DailyTestQuestion> kDayZeroQuestions = [
  DailyTestQuestion(
    item: const PracticeItem(
      id: 'day0_1',
      type: PracticeItemType.fillInBlank,
      context: 'You should avoid ___ too much sugar.',
      instruction: 'Fill in the blank with the correct form of the verb in '
          'brackets.',
      hint: '(eat)',
    ),
    topicId: 'gerundVsInfinitive',
    correctAnswer: 'eating',
    explanation: "After 'avoid', the next verb takes the -ing form, so it's "
        "'avoid eating'.",
    commonWrongAnswers: const [
      CommonWrongAnswer(
        answer: 'to eat',
        comment: "'Avoid' is followed by the -ing form, not 'to'. Say 'avoid "
            "eating'.",
      ),
      CommonWrongAnswer(
        answer: 'eat',
        comment: "After 'avoid' the verb takes -ing: 'avoid eating'.",
      ),
    ],
  ),
  DailyTestQuestion(
    item: const PracticeItem(
      id: 'day0_2',
      type: PracticeItemType.errorCorrection,
      context: 'She is best student in our class.',
      instruction: 'Find the mistake and rewrite the full corrected sentence.',
    ),
    topicId: 'articles',
    correctAnswer: 'She is the best student in our class',
    explanation: "'Best' compares her with everyone else, and there is only "
        "one best, so it needs 'the': 'the best student'.",
    commonWrongAnswers: const [
      CommonWrongAnswer(
        answer: 'She is a best student in our class',
        comment: "'Best' is a superlative, and superlatives take 'the': there "
            'is only one best.',
      ),
      CommonWrongAnswer(
        answer: 'She is best student in our class',
        comment: 'That is the same sentence. Look for the small word missing '
            "before 'best student'.",
      ),
    ],
  ),
  DailyTestQuestion(
    item: const PracticeItem(
      id: 'day0_3',
      type: PracticeItemType.errorCorrection,
      context: 'She can speaks three languages.',
      instruction: 'Find the mistake and rewrite the full corrected sentence.',
    ),
    topicId: 'modalVerbs',
    correctAnswer: 'She can speak three languages',
    explanation: "After 'can', the verb stays in its plain form, even with "
        "'she', so it's 'can speak'.",
    commonWrongAnswers: const [
      CommonWrongAnswer(
        answer: 'She can speaking three languages',
        comment: "After a modal like 'can', use the plain verb: 'can speak'.",
      ),
      CommonWrongAnswer(
        answer: 'She can to speak three languages',
        comment: 'Modals are followed by the plain verb without '
            "'to'.",
      ),
      CommonWrongAnswer(
        answer: 'She can speaks three languages',
        comment: "That is the same sentence. Look at the verb after 'can'.",
      ),
    ],
  ),
  DailyTestQuestion(
    item: const PracticeItem(
      id: 'day0_4',
      type: PracticeItemType.fillInBlank,
      context: 'Tom said he ___ call me the next day.',
      instruction: 'Put the verb in brackets into reported speech.',
      hint: '(will)',
    ),
    topicId: 'modalPastForms',
    correctAnswer: 'would',
    explanation: "When you report what someone said in the past, 'will' "
        "moves back to 'would': 'he would call me'.",
    commonWrongAnswers: const [
      CommonWrongAnswer(
        answer: 'will',
        comment: "After 'said' (past), 'will' moves back to 'would' in "
            'reported speech.',
      ),
      CommonWrongAnswer(
        answer: 'could',
        comment: "'Could' means 'was able to'. To report 'will', use "
            "'would'.",
      ),
    ],
  ),
  DailyTestQuestion(
    item: const PracticeItem(
      id: 'day0_5',
      type: PracticeItemType.fillInBlank,
      context: 'Yesterday I ___ a great film.',
      instruction: 'Fill in the blank with the correct form of the verb in '
          'brackets.',
      hint: '(see)',
    ),
    topicId: 'tenseSelection',
    correctAnswer: 'saw',
    explanation: "'Yesterday' is a finished time in the past, so the verb goes "
        "in the simple past: 'saw'.",
    commonWrongAnswers: const [
      CommonWrongAnswer(
        answer: 'have seen',
        comment: "With a finished time like 'yesterday', use the simple past: "
            "'saw'.",
      ),
      CommonWrongAnswer(
        answer: 'seen',
        comment: "'Seen' needs a helper verb. With 'yesterday', use the "
            "simple past 'saw'.",
      ),
      CommonWrongAnswer(
        answer: 'had seen',
        comment: "'Had seen' is for something before another past moment. "
            "With 'yesterday', use 'saw'.",
      ),
    ],
  ),
];
