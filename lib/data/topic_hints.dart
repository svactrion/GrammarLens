import '../models/topic.dart';

/// The Daily Test's topic hint cards (docs/question-screen-plan.md, item 2):
/// one fixed card per topic, written once by the owner and bundled, so it
/// needs no AI call and works offline. Reading a card changes nothing: no
/// score, no Monthly Climb step, no analytics, no state.
///
/// The texts are the owner's, verbatim; they were shortened (2026-10-12) to
/// fit above the "Your answer" row with the keyboard up at 375 × 667, which
/// `test/topic_hint_card_test.dart` guards. The card's title is the topic's
/// own title (`kTopics`).
const Map<TopicId, List<String>> kTopicHints = {
  TopicId.gerundVsInfinitive: [
    '+ -ing: enjoy, avoid, finish, keep',
    '+ to: want, decide, hope, plan',
    'Meaning changes: stop, remember, try',
    'After a preposition: always -ing',
  ],
  TopicId.modalVerbs: [
    'modal + base verb: no "to", no "-s"',
    'must: obligation · should: advice',
    'may / might / could: possibility',
    "mustn't ≠ don't have to",
  ],
  TopicId.modalPastForms: [
    'modal + have + past participle',
    "must / can't have: sure it did / didn't",
    'might / could have: maybe it did',
    "should have: right, but it didn't happen",
  ],
  TopicId.tenseSelection: [
    'Past simple: finished time (ago, in 2020)',
    'Present perfect: up to now (since, for, yet)',
    'Past perfect: before another past event',
    'Continuous: in progress at that moment',
  ],
  TopicId.articles: [
    'a / an: one of many, or first mention',
    'an before a vowel sound: an hour',
    'the: specific, known, or the only one',
    'No article: general plural or uncountable',
  ],
};
