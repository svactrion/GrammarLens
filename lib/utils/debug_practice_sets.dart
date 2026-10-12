import '../models/practice_item.dart';
import '../models/practice_set.dart';
import '../models/topic.dart';

/// Fixed multi-blank practice sets for checking the answer boxes on a device
/// (question screen B3) before the proxy's "at most 4 blanks" rule is
/// deployed, when a live set rarely has more than one blank. Opened from
/// the Debug panel only, so a release build, which has no Debug panel,
/// compiles them out. Answers are scored for real, through the proxy.
abstract final class DebugPracticeSets {
  /// Topic `articles`, so every box has the "—" (no article) button: 2, 3
  /// and 4 blanks, with no-article blanks at a sentence start (the next word
  /// takes a capital) and in mid-sentence.
  static const PracticeSet articles = PracticeSet(
    topicId: 'articles',
    items: [
      PracticeItem(
        id: 'debug_articles_2',
        type: PracticeItemType.fillInBlank,
        context: '____ honesty matters to her, so she gave me ____ honest '
            'answer.',
        instruction: 'Fill in each blank with a, an or the, or tap — for no '
            'article.',
      ),
      PracticeItem(
        id: 'debug_articles_3',
        type: PracticeItemType.fillInBlank,
        context: 'We had ____ lunch at ____ small café near ____ station.',
        instruction: 'Fill in each blank with a, an or the, or tap — for no '
            'article.',
      ),
      PracticeItem(
        id: 'debug_articles_4',
        type: PracticeItemType.fillInBlank,
        context: '____ sun was setting when ____ old man sat down on ____ '
            'bench and opened ____ newspaper.',
        instruction: 'Fill in each blank with a, an or the, or tap — for no '
            'article.',
      ),
    ],
  );

  /// Topic `gerundVsInfinitive`: multi-blank boxes without the "—" button.
  static const PracticeSet gerundVsInfinitive = PracticeSet(
    topicId: 'gerundVsInfinitive',
    items: [
      PracticeItem(
        id: 'debug_gerund_2',
        type: PracticeItemType.fillInBlank,
        context: 'I enjoy ____ (swim), but this year I have decided ____ '
            '(learn) tennis.',
        instruction: 'Fill in each blank with the right form of the verb.',
      ),
      PracticeItem(
        id: 'debug_gerund_3',
        type: PracticeItemType.fillInBlank,
        context: 'She stopped ____ (smoke) last year, she avoids ____ (go) '
            'to smoky bars, and she plans ____ (run) a marathon.',
        instruction: 'Fill in each blank with the right form of the verb.',
      ),
    ],
  );

  static TopicId topicOf(PracticeSet set) => TopicId.values.byName(set.topicId);
}
