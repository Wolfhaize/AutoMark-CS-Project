/// Parses raw OCR answer text into a list of cleaned answers (by line).
List<String> parseAnswers(String rawText) {
  return rawText
      .trim()
      .split(RegExp(r'[\n\r]+'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
}

/// Grades a student's answers against the structured answer key.
///
/// Supports:
/// - Objective: Exact match (e.g., "A").
/// - Keyword: Checks if at least 50% of keywords are found in the answer.
/// - Weighted Keyword: Same as keyword, but adds a weight to the score.
///
/// Parameters:
/// - [studentAnswers]: Parsed answers from OCR.
/// - [answerKey]: List of answer entries (Map with 'type', 'answer', 'keywords', 'weight').
///
/// Returns:
/// - Total score as an integer.
int gradeAnswers(List<String> studentAnswers, List<dynamic> answerKey) {
  int score = 0;

  for (int i = 0; i < answerKey.length && i < studentAnswers.length; i++) {
    final rawStudentAnswer = studentAnswers[i]
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .trim();

    final item = answerKey[i];

    if (item is! Map<String, dynamic>) continue;

    final type = item['type'];
    final answer = (item['answer'] ?? '').toString().toLowerCase().trim();
    final keywords = List<String>.from(item['keywords'] ?? []).map((k) => k.toLowerCase().trim()).toList();
    final weight = item['weight'] is num ? (item['weight'] as num).toInt() : 1;

    if (type == 'Objective') {
      final cleanedAnswer = answer.replaceAll(RegExp(r'[^\w\s]'), '');
      if (rawStudentAnswer == cleanedAnswer) {
        score += 1;
      }
    } else if (type == 'Keyword') {
      if (keywords.isEmpty) continue;

      final matched = keywords.where((k) => rawStudentAnswer.contains(k)).length;
      final matchRatio = matched / keywords.length;

      if (matchRatio >= 0.5) {
        score += weight;
      }
    }
  }

  return score;
}