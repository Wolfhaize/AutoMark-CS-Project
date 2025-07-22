import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AIService {
  final _apiKey = dotenv.env['OPENAI_API_KEY'];

  /// Grades a single student's answer using AI, given the model answer and allocated marks.
  Future<Map<String, dynamic>> gradeAnswer({
    required String studentAnswer,
    required String modelAnswer,
    required int allocatedMarks,
  }) async {
    final url = Uri.parse("https://api.openai.com/v1/chat/completions");

    final headers = {
      'Authorization': 'Bearer $_apiKey',
      'Content-Type': 'application/json',
    };

    final prompt = """
You're an AI grading assistant.

Compare the student's answer with the model answer.

- Give a score between 0 and $allocatedMarks (no decimal points).
- Provide brief feedback explaining the score.
- Only return a JSON object with 'score' and 'feedback'.

Example Output:
{
  "score": 4,
  "feedback": "Good attempt but missing key details like X and Y."
}

Model Answer:
$modelAnswer

Student Answer:
$studentAnswer

Return the result now.
""";

    final body = jsonEncode({
      "model": "gpt-4-turbo",
      "messages": [
        {
          "role": "system",
          "content":
              "You're an AI grader that scores answers based on allocated marks."
        },
        {
          "role": "user",
          "content": prompt
        }
      ],
      "temperature": 0.2,
    });

    final response = await http.post(url, headers: headers, body: body);

    if (response.statusCode != 200) {
      throw Exception("OpenAI API error: ${response.body}");
    }

    final data = jsonDecode(response.body);
    final message = data['choices'][0]['message']['content'];

    // Extract the JSON from the response safely
    final match = RegExp(r'\{[\s\S]*\}').firstMatch(message ?? '');
    if (match != null) {
      final jsonString = match.group(0);
      return jsonDecode(jsonString!);
    }

    // Fallback if parsing fails
    return {
      "score": 0,
      "feedback": message ?? "Could not parse AI response."
    };
  }

  /// Grades a full script by looping through all questions in the answer key and student answers.
  Future<Map<String, dynamic>> gradeScript({
    required List<Map<String, dynamic>> answerKey,
    required Map<String, String> studentAnswers,
  }) async {
    int totalScore = 0;
    int totalPossible = 0;

    List<Map<String, dynamic>> details = [];

    for (var entry in answerKey) {
      final question = entry['question'];
      final modelAnswer = entry['modelAnswer'];

      // Convert marks to int explicitly:
      final marksDynamic = entry['marks'];
      final marks = (marksDynamic is num) ? marksDynamic.toInt() : int.parse(marksDynamic.toString());

      final studentAnswer = studentAnswers[question] ?? "";

      try {
        final result = await gradeAnswer(
          studentAnswer: studentAnswer,
          modelAnswer: modelAnswer,
          allocatedMarks: marks,
        );

        // Convert score to int explicitly:
        final scoreDynamic = result['score'] ?? 0;
        final questionScore = (scoreDynamic is num) ? scoreDynamic.toInt() : int.parse(scoreDynamic.toString());

        totalScore += questionScore;
        totalPossible += marks;

        details.add({
          "question": question,
          "modelAnswer": modelAnswer,
          "studentAnswer": studentAnswer,
          "allocatedMarks": marks,
          "score": questionScore,
          "feedback": result['feedback'] ?? "",
        });
      } catch (e) {
        details.add({
          "question": question,
          "modelAnswer": modelAnswer,
          "studentAnswer": studentAnswer,
          "allocatedMarks": marks,
          "score": 0,
          "feedback": "Error grading this question: $e",
        });
        totalPossible += marks; // still add possible marks
      }
    }

    final overallFeedback = _generateOverallFeedback(totalScore, totalPossible);

    return {
      "totalScore": totalScore,
      "totalPossible": totalPossible,
      "percentage": (totalPossible > 0) ? (totalScore / totalPossible * 100).toStringAsFixed(1) : "0.0",
      "feedback": overallFeedback,
      "details": details,
    };
  }

  /// Generates overall feedback based on the total score.
  String _generateOverallFeedback(int totalScore, int totalPossible) {
    if (totalPossible == 0) return "No questions to grade.";

    final percent = (totalScore / totalPossible) * 100;

    if (percent >= 80) {
      return "Excellent work! Keep it up.";
    } else if (percent >= 60) {
      return "Good effort, but there's room for improvement.";
    } else if (percent >= 40) {
      return "Fair attempt, consider revising key concepts.";
    } else {
      return "Needs significant improvement. Please review the material carefully.";
    }
  }
}
