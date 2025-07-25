import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:string_similarity/string_similarity.dart'; // For similarity scoring

class AIService {
  final _openAiKey = dotenv.env['OPENAI_API_KEY'];
  final _groqKey = dotenv.env['GROQ_API_KEY'];

  final _openAiUrl = Uri.parse("https://api.openai.com/v1/chat/completions");
  final _groqUrl = Uri.parse("https://api.groq.com/openai/v1/chat/completions");

  /// Hybrid Grade Answer - Combines LLM, Similarity & Keyword Matching
  Future<Map<String, dynamic>> hybridGradeAnswer({
    required String studentAnswer,
    required String modelAnswer,
    required int allocatedMarks,
    bool useGroq = true,
  }) async {
    // 1. Similarity Scoring
    final similarity = studentAnswer.similarityTo(modelAnswer); // Returns 0-1

    // 2. Keyword Matching
    final keywords = _extractKeywords(modelAnswer);
    final matchCount =
        keywords
            .where(
              (kw) => studentAnswer.toLowerCase().contains(kw.toLowerCase()),
            )
            .length;
    final keywordScore = (matchCount / keywords.length).clamp(0.0, 1.0);

    // 3. LLM Grading
    final llmResult = await gradeAnswer(
      studentAnswer: studentAnswer,
      modelAnswer: modelAnswer,
      allocatedMarks: allocatedMarks,
      useGroq: useGroq,
    );

    final llmScore = (llmResult['score'] as num).toDouble();
    final llmMarks = llmScore / allocatedMarks;

    // 4. Combine (weighted average)
    final hybridScoreRatio =
        (0.4 * similarity) + (0.3 * keywordScore) + (0.3 * llmMarks);
    final finalScore = (hybridScoreRatio * allocatedMarks).round();

    return {
      "score": finalScore,
      "feedback":
          "Similarity: ${(similarity * 100).toStringAsFixed(1)}%, "
          "Keywords: ${(keywordScore * 100).toStringAsFixed(1)}%, "
          "AI Marks: ${llmScore.toStringAsFixed(1)} / $allocatedMarks.\n"
          "Overall: $finalScore / $allocatedMarks.\n\n"
          "${llmResult['feedback']}",
    };
  }

  /// Simple keyword extraction (split model answer into important terms)
  List<String> _extractKeywords(String text) {
    final words =
        text.split(RegExp(r'[\s,.]+')).map((w) => w.toLowerCase()).toSet();
    words.removeWhere((w) => w.length <= 3); // remove short/common words
    return words.toList();
  }

  /// Existing LLM Grading (keep this for fallback / AI feedback)
  Future<Map<String, dynamic>> gradeAnswer({
    required String studentAnswer,
    required String modelAnswer,
    required int allocatedMarks,
    bool useGroq = true,
  }) async {
    final url = useGroq ? _groqUrl : _openAiUrl;
    final apiKey = useGroq ? _groqKey : _openAiKey;

    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };

    final prompt = """
You're an AI grader.

Compare the student's answer to the model answer.

- Give a score between 0 and $allocatedMarks (no decimals).
- Provide short feedback.

Return this JSON:

{
  "score": X,
  "feedback": "Your feedback."
}

If the student's answer is blank, give 0 and say "No attempt made."

Model Answer:
$modelAnswer

Student Answer:
$studentAnswer
""";

    final body = jsonEncode({
      "model": "llama3-70b-8192",
      "messages": [
        {"role": "system", "content": "Return JSON only: score and feedback."},
        {"role": "user", "content": prompt},
      ],
      "temperature": 0.2,
    });

    final response = await http.post(url, headers: headers, body: body);

    if (response.statusCode != 200) {
      throw Exception("AI API error: ${response.body}");
    }

    final data = jsonDecode(response.body);
    final message = data['choices'][0]['message']['content'];
    final match = RegExp(r'\{[\s\S]*\}').firstMatch(message ?? '');
    if (match != null) {
      return jsonDecode(match.group(0)!);
    }

    return {"score": 0, "feedback": "Unstructured AI output."};
  }

  /// Grade the whole script using Hybrid Grading
  Future<Map<String, dynamic>> gradeScript({
    required List<Map<String, dynamic>> answerKey,
    required Map<String, String> studentAnswers,
    bool useGroq = true,
  }) async {
    int totalScore = 0;
    int totalPossible = 0;
    List<Map<String, dynamic>> details = [];

    for (var entry in answerKey) {
      final question = entry['question'];
      final modelAnswer = entry['modelAnswer'];
      final marks = (entry['marks'] as num).toInt();
      final studentAnswer = studentAnswers[question] ?? "";

      final result = await hybridGradeAnswer(
        studentAnswer: studentAnswer,
        modelAnswer: modelAnswer,
        allocatedMarks: marks,
        useGroq: useGroq,
      );

      final score = (result['score'] as num).toInt();

      totalScore += score;
      totalPossible += marks;

      details.add({
        "question": question,
        "modelAnswer": modelAnswer,
        "studentAnswer": studentAnswer,
        "allocatedMarks": marks,
        "score": score,
        "feedback": result['feedback'],
      });
    }

    return {
      "totalScore": totalScore,
      "totalPossible": totalPossible,
      "percentage":
          (totalPossible > 0)
              ? (totalScore / totalPossible * 100).toStringAsFixed(1)
              : "0.0",
      "feedback": _generateOverallFeedback(totalScore, totalPossible),
      "details": details,
    };
  }

  String _generateOverallFeedback(int score, int total) {
    final percent = (score / total) * 100;
    if (percent >= 80) return "Excellent work!";
    if (percent >= 60) return "Good effort, some revision needed.";
    if (percent >= 40) return "Fair attempt, revise concepts.";
    return "Needs improvement.";
  }

  /// For OCR answer extraction (Student Answers only)
  Future<Map<String, String>> extractAnswersFromText(
    String rawText, {
    bool useGroq = true,
    List<String>? guideQuestions,
  }) async {
    final url = useGroq ? _groqUrl : _openAiUrl;
    final apiKey = useGroq ? _groqKey : _openAiKey;

    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };

    final guideSection =
        guideQuestions != null && guideQuestions.isNotEmpty
            ? "Here are the actual questions:\n${guideQuestions.asMap().entries.map((e) => "${e.key + 1}. ${e.value}").join("\n")}\n\n"
            : "";

    final prompt = """
You are an AI exam assistant.

Extract student answers from the provided exam text.

Students may answer in any format:
- 1: Answer
- 1. Answer
- 1) Answer
- Copy the full question first, then answer it below.
- Continuous essay style.

Your task:
- For each question, extract the best matching answer.
- Use the question numbers (1, 2, 3, etc.) to organize the output.
- If the student skips a question, return an empty string for that question.

${guideSection}Student's Answer Text:

$rawText

Return only valid JSON in this format:

{
  "1": "Student's answer to question 1",
  "2": "Student's answer to question 2",
  "3": "Student's answer to question 3"
}
""";

    final body = jsonEncode({
      "model": "llama3-70b-8192",
      "messages": [
        {"role": "system", "content": "Extract answers. Return JSON map only."},
        {"role": "user", "content": prompt},
      ],
      "temperature": 0,
    });

    final response = await http.post(url, headers: headers, body: body);

    if (response.statusCode != 200) {
      throw Exception("AI API error: ${response.body}");
    }

    final data = jsonDecode(response.body);
    final message = data['choices'][0]['message']['content'];

    final Map<String, dynamic> rawResult = jsonDecode(message);

    final Map<String, String> result = rawResult.map(
      (key, value) => MapEntry(key, value.toString()),
    );

    return result;
  }

  ///Extract structured Marking Guide (Questions + Model Answers + Marks)
  Future<List<Map<String, dynamic>>> extractMarkingGuideFromText(
    String rawText, {
    bool useGroq = true,
  }) async {
    final url = useGroq ? _groqUrl : _openAiUrl;
    final apiKey = useGroq ? _groqKey : _openAiKey;

    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };

    final prompt = """
Extract a structured marking guide from this text.

Return a list of objects like:

[
  {"question": "Question here", "modelAnswer": "Answer here", "marks": X},
  {"question": "Question here", "modelAnswer": "Answer here", "marks": X}
]

- If marks are missing, set "marks": null. Do not guess marks.
- Only return valid JSON.

Here is the text:

$rawText
""";

    final body = jsonEncode({
      "model": "llama3-70b-8192",
      "messages": [
        {"role": "system", "content": "Return structured JSON array only."},
        {"role": "user", "content": prompt},
      ],
      "temperature": 0,
    });

    final response = await http.post(url, headers: headers, body: body);

    if (response.statusCode != 200) {
      throw Exception("AI API error: ${response.body}");
    }

    final data = jsonDecode(response.body);
    final message = data['choices'][0]['message']['content'];

    return List<Map<String, dynamic>>.from(jsonDecode(message));
  }
}
