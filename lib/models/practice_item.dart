enum PracticeItemType { fillInBlank, errorCorrection, sentenceWriting }

extension PracticeItemTypeJson on PracticeItemType {
  static PracticeItemType fromJson(String value) {
    switch (value) {
      case 'fill_in_blank':
        return PracticeItemType.fillInBlank;
      case 'error_correction':
        return PracticeItemType.errorCorrection;
      case 'sentence_writing':
        return PracticeItemType.sentenceWriting;
    }
    throw ArgumentError('Unknown practice item type: $value');
  }

  String toJson() {
    switch (this) {
      case PracticeItemType.fillInBlank:
        return 'fill_in_blank';
      case PracticeItemType.errorCorrection:
        return 'error_correction';
      case PracticeItemType.sentenceWriting:
        return 'sentence_writing';
    }
  }
}

class PracticeItem {
  final String id;
  final PracticeItemType type;
  final String? context;
  final String instruction;
  final String? hint;

  const PracticeItem({
    required this.id,
    required this.type,
    this.context,
    required this.instruction,
    this.hint,
  });

  factory PracticeItem.fromJson(Map<String, dynamic> json) => PracticeItem(
        id: json['id'] as String,
        type: PracticeItemTypeJson.fromJson(json['type'] as String),
        context: json['context'] as String?,
        instruction: json['instruction'] as String,
        hint: json['hint'] as String?,
      );

  /// Round-trips through [fromJson] — needed so items can be cached locally
  /// (Daily Test's generated set, saved once per day) rather than only ever
  /// flowing one-way from the API into memory.
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.toJson(),
        if (context != null) 'context': context,
        'instruction': instruction,
        if (hint != null) 'hint': hint,
      };

  /// [context] and [instruction] combined into one string, for places that
  /// need the item's full text as a single value (scoring payload, saved
  /// error entries) rather than the two display blocks.
  String get fullText =>
      (context == null || context!.trim().isEmpty)
          ? instruction
          : '$context\n$instruction';
}
