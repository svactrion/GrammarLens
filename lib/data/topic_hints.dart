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

/// B2 (1.4.0; owner, 2026-11-02): the lines of a card that list example
/// words after a label ("+ -ing: enjoy, avoid, finish, keep"), by index in
/// [kTopicHints]. On these lines an example the question itself uses is
/// the word that decides the answer, so [hintPointsFor] leaves it out.
/// Only the Gerund vs. Infinitive verb lists: the other cards' words
/// ("the", "since", "should") are signals the card is meant to map to a
/// form, not the answer.
const Map<TopicId, Set<int>> kHintExampleLines = {
  TopicId.gerundVsInfinitive: {0, 1, 2},
};

/// The card's points for one question: [kTopicHints] with every example on
/// a [kHintExampleLines] line removed when its word occurs in
/// [questionText] (the item's context, instruction and hint), whole word,
/// case-insensitive, in any regular inflection ([hintWordForms]). A line
/// that loses every example keeps its label alone ("+ -ing"). Every other
/// line, and every other topic, is returned as it is. Null for a topic
/// without a card.
///
/// The recorded case (2026-10-16): "You should avoid ___ too much sugar."
/// gave the answer away on "+ -ing: enjoy, avoid, finish, keep"; the card
/// now reads "+ -ing: enjoy, finish, keep".
List<String>? hintPointsFor(TopicId topic, String questionText) {
  final points = kTopicHints[topic];
  if (points == null) return null;
  final lines = kHintExampleLines[topic];
  if (lines == null) return points;
  final words = {
    for (final m in RegExp(r"[a-z]+").allMatches(questionText.toLowerCase()))
      m.group(0)!,
  };
  return [
    for (final (i, point) in points.indexed)
      lines.contains(i) ? _withoutUsedExamples(point, words) : point,
  ];
}

String _withoutUsedExamples(String point, Set<String> questionWords) {
  final colon = point.indexOf(':');
  if (colon < 0) return point;
  final label = point.substring(0, colon);
  final examples = point
      .substring(colon + 1)
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty);
  final kept = [
    for (final example in examples)
      if (!hintWordForms(example).any(questionWords.contains)) example,
  ];
  return kept.isEmpty ? label : '$label: ${kept.join(', ')}';
}

/// [word] and its regular inflections: -s, -es, -ed, -d, -ing, the final
/// consonant doubled (stop → stopped, stopping), -e dropped before -ing
/// (decide → deciding), and y → -ies / -ied (try → tries, tried), plus
/// the irregular past of a listed word ([_irregularForms]: "She kept
/// talking"). Over-generated forms ("keepped") match nothing and are
/// harmless.
Set<String> hintWordForms(String word) {
  final w = word.toLowerCase();
  final forms = {
    w,
    '${w}s',
    '${w}es',
    '${w}ed',
    '${w}d',
    '${w}ing',
    ...?_irregularForms[w],
  };
  if (w.endsWith('e')) forms.add('${w.substring(0, w.length - 1)}ing');
  if (w.endsWith('y')) {
    final stem = w.substring(0, w.length - 1);
    forms.addAll({'${stem}ies', '${stem}ied'});
  }
  final last = w.isEmpty ? '' : w[w.length - 1];
  if (last.isNotEmpty && !'aeiouwy'.contains(last)) {
    forms.addAll({'$w${last}ed', '$w${last}ing'});
  }
  return forms;
}

/// The irregular past forms of the words on the [kHintExampleLines] lines.
/// The other listed words are regular.
const Map<String, Set<String>> _irregularForms = {
  'keep': {'kept'},
};
