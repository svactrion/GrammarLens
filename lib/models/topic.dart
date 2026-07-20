enum TopicId {
  gerundVsInfinitive,
  modalVerbs,
  modalPastForms,
  tenseSelection,
  articles,
}

class Topic {
  final TopicId id;
  final String title;
  final String description;

  const Topic({
    required this.id,
    required this.title,
    required this.description,
  });
}
