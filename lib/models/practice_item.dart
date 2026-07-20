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
  final String prompt;
  final String? hint;

  const PracticeItem({
    required this.id,
    required this.type,
    required this.prompt,
    this.hint,
  });

  factory PracticeItem.fromJson(Map<String, dynamic> json) => PracticeItem(
        id: json['id'] as String,
        type: PracticeItemTypeJson.fromJson(json['type'] as String),
        prompt: json['prompt'] as String,
        hint: json['hint'] as String?,
      );
}
