import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/data/topics.dart';
import 'package:grammar_lens/models/topic.dart';
import 'package:grammar_lens/utils/text_format.dart';

import 'support/l10n_support.dart';

/// 1.4.0 B4.4: topic titles moved to the strings. Weak spots used to compare
/// their humanized rule with the topic's English title; they now compare it
/// with the topic id humanized ([ruleIsTopic]), which must be the same
/// English title for every topic, so nothing changes in English.
void main() {
  test('every topic id humanizes to its English title', () {
    for (final topic in kTopics) {
      expect(humanizeSlug(topic.id.name), topic.title(en),
          reason: topic.id.name);
    }
  });

  test('a Daily Test weak spot (error type = topic id) is its topic', () {
    final articles = topicById(TopicId.articles);
    expect(ruleIsTopic('articles', articles), isTrue);
    expect(weakSpotTitle('articles', articles, en), 'Articles');
    final gerund = topicById(TopicId.gerundVsInfinitive);
    expect(ruleIsTopic('gerund_vs_infinitive', gerund), isTrue);
    expect(ruleIsTopic('gerundVsInfinitive', gerund), isTrue);
  });

  test('a scorer rule keeps its own English title', () {
    final articles = topicById(TopicId.articles);
    expect(ruleIsTopic('article_use', articles), isFalse);
    expect(weakSpotTitle('article_use', articles, en), 'Article Use');
  });
}
