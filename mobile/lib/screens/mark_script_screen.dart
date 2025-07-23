import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/grading_logic.dart';
import '../services/ai_service.dart';

class MarkScriptScreen extends StatefulWidget {
  final Map<String, dynamic> script;
  final List<dynamic> guideAnswers;

  const MarkScriptScreen({
    super.key,
    required this.script,
    required this.guideAnswers,
  });

  @override
  State<MarkScriptScreen> createState() => _MarkScriptScreenState();
}

class _MarkScriptScreenState extends State<MarkScriptScreen> {
  bool _isLoading = false;
  int? _score;
  int? _total;
  String? _feedback;
  final _manualController = TextEditingController();

  // Returns Map<QuestionID, Answer>
  Map<String, String> parseAnswers(String ocrText) {
    final lines = ocrText.split('\n');
    final Map<String, String> answers = {};

    for (var line in lines) {
      if (line.trim().isEmpty) continue;

      final parts = line.split(':');
      if (parts.length >= 2) {
        final question = parts[0].trim();
        final answer = parts.sublist(1).join(':').trim();
        answers[question] = answer;
      }
    }
    return answers;
  }

  // Returns List<Answer> — only values, for auto marking function
  List<String> parseAnswersList(String ocrText) {
    final map = parseAnswers(ocrText);
    return map.values.toList();
  }

  Future<void> _autoMark() async {
    setState(() => _isLoading = true);

    try {
      final ocrText = widget.script['ocrText'] ?? '';
      if (ocrText.trim().isEmpty) {
        _showSnackBar("OCR text is empty. Cannot mark.", isError: true);
        return;
      }

      // Use parseAnswersList here to get List<String> for gradeAnswers
      final parsedAnswers = parseAnswersList(ocrText);
      final score = gradeAnswers(parsedAnswers, widget.guideAnswers);

      setState(() {
        _score = score;
        _total = widget.guideAnswers.fold<int>(0, (sum, q) => sum + (q['marks'] as int));
        _feedback = null;
      });

      await _saveResult(score, _total!, method: 'auto');
    } catch (e) {
      _showSnackBar("Auto-marking failed: $e", isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _aiMark() async {
    setState(() => _isLoading = true);

    try {
      final ocrText = widget.script['ocrText'] ?? '';
      if (ocrText.trim().isEmpty) {
        _showSnackBar("OCR text is empty. Cannot mark.", isError: true);
        return;
      }

      final ai = AIService();

      // Use parseAnswers to get Map<String, String> for AI grading
      final studentAnswers = parseAnswers(ocrText);

      final answerKey = widget.guideAnswers.map((e) => {
            "question": e['question'],
            "modelAnswer": e['modelAnswer'],
            "marks": e['marks'],
          }).toList();

      final result = await ai.gradeScript(
        answerKey: answerKey,
        studentAnswers: studentAnswers,
      );

      setState(() {
        _score = result['totalScore'];
        _total = result['totalPossible'];
        _feedback = result['feedback'];
      });

      await _saveResult(
        _score!,
        _total!,
        method: 'ai',
        feedback: _feedback,
        details: result['details'],
      );
    } catch (e) {
      _showSnackBar("AI marking failed: $e", isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveManualScore() async {
    final score = int.tryParse(_manualController.text.trim());
    if (score == null || score < 0) {
      _showSnackBar("⚠ Enter a valid positive number", isError: true);
      return;
    }
    if (score > 100) {
      _showSnackBar("⚠ Score too high! Max is 100", isError: true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirm Manual Score"),
        content: Text("Submit $score as the final score?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Confirm")),
        ],
      ),
    );

    if (confirmed == true) {
      await _saveResult(score, null, method: 'manual');
    }
  }

  Future<void> _saveResult(
    int score,
    int? total, {
    required String method,
    String? feedback,
    List<dynamic>? details,
  }) async {
    final script = widget.script;
    final id = script['id'];

    await FirebaseFirestore.instance.collection('results').add({
      'name': script['name'],
      'score': score,
      'total': total ?? 0,
      'method': method,
      'feedback': feedback,
      'details': details,
      'timestamp': Timestamp.now(),
    });

    if (id != null) {
      await FirebaseFirestore.instance.collection('scripts').doc(id).update({
        'status': 'marked',
        'score': score,
        'total': total,
        'method': method,
        'feedback': feedback,
        'details': details,
      });
    }

    _showSnackBar("✅ Script marked successfully!");
    Navigator.pop(context);
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    _manualController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final script = widget.script;

    final submissionTime = script['timestamp'] != null
        ? (script['timestamp'] as Timestamp).toDate()
        : null;

    return Scaffold(
      appBar: AppBar(title: Text("Mark Script - ${script['name']}")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (submissionTime != null)
                    Text(
                      "Submitted: ${submissionTime.toLocal()}",
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  const SizedBox(height: 12),
                  const Text("Extracted Script Text:",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey.shade100,
                      ),
                      child: SingleChildScrollView(
                        child: Text(script['ocrText'] ?? 'No text'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.bolt),
                          label: const Text("Auto Mark"),
                          onPressed: _autoMark,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            backgroundColor: Colors.blue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.smart_toy),
                          label: const Text("AI Mark"),
                          onPressed: _aiMark,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            backgroundColor: const Color.fromARGB(255, 34, 20, 58),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _manualController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Enter Manual Score",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text("Submit Manual Score"),
                    onPressed: _saveManualScore,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                  ),
                  if (_score != null) ...[
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        "Score: $_score / $_total",
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green),
                      ),
                    ),
                  ],
                  if (_feedback != null) ...[
                    const SizedBox(height: 12),
                    const Text("Overall Feedback:",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(_feedback!,
                        style: const TextStyle(color: Colors.black87)),
                  ],
                ],
              ),
      ),
    );
  }
}
