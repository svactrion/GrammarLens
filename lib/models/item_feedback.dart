import '../utils/blank_assembly.dart';

/// The scorer's verdict on one blank of a practice question (1.4.0 D11,
/// server package report §4.1): the correct form for that blank alone,
/// whether the learner's answer is accepted, and a one-sentence note. A
/// single-answer item has exactly one entry. The learner's own text is not
/// in the response: the client pairs an entry with the box it took at
/// Submit ([BlankAnswer]) by [index].
class BlankFeedback {
  final int index;
  final String correctAnswer;
  final bool accepted;
  final String note;

  const BlankFeedback({
    required this.index,
    required this.correctAnswer,
    required this.accepted,
    required this.note,
  });

  BlankFeedback copyWith({bool? accepted}) => BlankFeedback(
        index: index,
        correctAnswer: correctAnswer,
        accepted: accepted ?? this.accepted,
        note: note,
      );

  Map<String, Object> toJson() => {
        'index': index,
        'correctAnswer': correctAnswer,
        'accepted': accepted,
        'note': note,
      };

  /// Strict on purpose: one entry with a missing or mistyped field makes
  /// the whole list unusable, and the caller falls back to the paragraph.
  static BlankFeedback? _fromJson(Object? json) {
    if (json is! Map) return null;
    final index = json['index'];
    final correctAnswer = json['correctAnswer'];
    final accepted = json['accepted'];
    final note = json['note'];
    if (index is! int ||
        correctAnswer is! String ||
        accepted is! bool ||
        note is! String) {
      return null;
    }
    return BlankFeedback(
      index: index,
      correctAnswer: correctAnswer,
      accepted: accepted,
      note: note,
    );
  }

  /// The additive rule (report §4.3): a list whose every entry has the four
  /// fields with the right types and whose indexes are exactly 0 … n − 1 in
  /// order. Anything else (the old proxy, an old stored record, a malformed
  /// output) reads as null, so the client renders today's paragraph.
  static List<BlankFeedback>? listFromJson(Object? json) {
    if (json is! List || json.isEmpty) return null;
    final out = <BlankFeedback>[];
    for (final entry in json) {
      final parsed = _fromJson(entry);
      if (parsed == null || parsed.index != out.length) return null;
      out.add(parsed);
    }
    return out;
  }
}

class ItemFeedback {
  final String itemId;
  final bool isCorrect;
  final bool isSkipped;
  final String? errorType;
  final String? rule;
  final String correctedAnswer;
  final String explanation;

  /// The whole-item lesson, two sentences at most (1.4.0 D11). Null from
  /// the old proxy; [explanation] then carries everything, as before.
  final String? summary;

  /// One verdict per blank (one entry for a single-answer item), or null
  /// when the response has none that parses ([BlankFeedback.listFromJson]).
  final List<BlankFeedback>? blanks;

  const ItemFeedback({
    required this.itemId,
    required this.isCorrect,
    required this.isSkipped,
    this.errorType,
    this.rule,
    required this.correctedAnswer,
    required this.explanation,
    this.summary,
    this.blanks,
  });

  /// [isSkipped] is decided by our own code from the user's actual answer
  /// text, not parsed from the model's response — the model's wording for
  /// "left blank" varies run to run (e.g. "You left this one blank",
  /// "Nothing was written here"), so it can't be matched reliably. See
  /// ClaudeService.scoreAnswers, which computes it before calling this.
  ///
  /// [hasUnfilledBlank] is decided the same way: a partial multi-blank
  /// answer keeps a `____` for each box left empty (1.4.0 B8, owner
  /// 2026-10-31), and such an answer is never correct whatever the model
  /// says, so [isCorrect] is forced false. The model's error type is kept
  /// as returned; when it gave none, no error entry is saved.
  ///
  /// [userBlanks] is the per-box snapshot taken at Submit (B8). With the
  /// scorer's per-blank verdicts (1.4.0 D11) and a snapshot of the same
  /// length, the verdict is made exact: a box that is not filled is never
  /// accepted (the box is visibly empty; the model may have scored it from
  /// context), and [isCorrect] is "every blank accepted". Without a
  /// snapshot, or with a length that does not match, the parsed blanks are
  /// kept as they are and the rule above decides, so a 1.4.0 client against
  /// the old proxy, and an old stored record, behave exactly as before.
  factory ItemFeedback.fromJson(
    Map<String, dynamic> json, {
    required bool isSkipped,
    bool hasUnfilledBlank = false,
    List<BlankAnswer>? userBlanks,
  }) {
    var blanks = BlankFeedback.listFromJson(json['blanks']);
    final modelVerdict = json['isCorrect'] as bool;
    bool isCorrect;
    if (blanks != null &&
        userBlanks != null &&
        userBlanks.length == blanks.length) {
      blanks = [
        for (var i = 0; i < blanks.length; i++)
          userBlanks[i].isFilled
              ? blanks[i]
              : blanks[i].copyWith(accepted: false),
      ];
      isCorrect = blanks.every((b) => b.accepted);
    } else {
      isCorrect = !hasUnfilledBlank && modelVerdict;
    }
    final summary = json['summary'];
    return ItemFeedback(
      itemId: json['itemId'] as String,
      isCorrect: isCorrect,
      isSkipped: isSkipped,
      errorType: json['errorType'] as String?,
      rule: json['rule'] as String?,
      correctedAnswer: json['correctedAnswer'] as String,
      explanation: json['explanation'] as String,
      summary: summary is String && summary.trim().isNotEmpty
          ? summary.trim()
          : null,
      blanks: blanks,
    );
  }
}
