class AnswerEntry {
  final String question;
  final String modelAnswer;
  final int marks;

  AnswerEntry({
    required this.question,
    required this.modelAnswer,
    required this.marks,
  });

  factory AnswerEntry.fromJson(Map<String, dynamic> json) {
    return AnswerEntry(
      question: json['question'] ?? '',
      modelAnswer: json['modelAnswer'] ?? '',
      marks: json['marks'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'question': question,
      'modelAnswer': modelAnswer,
      'marks': marks,
    };
  }
}