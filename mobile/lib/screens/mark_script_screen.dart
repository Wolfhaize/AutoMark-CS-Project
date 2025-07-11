import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/grading_logic.dart';

class MarkScriptScreen extends StatefulWidget {
  const MarkScriptScreen({super.key});

  @override
  State<MarkScriptScreen> createState() => _MarkScriptScreenState();
}

class _MarkScriptScreenState extends State<MarkScriptScreen> {
  bool _isLoading = false;
  int? _score;
  int? _total;
  final _manualController = TextEditingController();

  Future<void> _autoMark(Map<String, dynamic> script) async {
    setState(() => _isLoading = true);

    try {
      final answerKeySnap = await FirebaseFirestore.instance
          .collection('answer_key')
          .doc('latest')
          .get();

      if (!answerKeySnap.exists) {
        _showSnackBar("⚠ No answer key found", isError: true);
        setState(() => _isLoading = false);
        return;
      }

      final answerKey = answerKeySnap['answers'] as List<dynamic>;
      final parsedAnswers = parseAnswers(script['ocrText']);
      final score = gradeAnswers(parsedAnswers, answerKey);

      setState(() {
        _score = score;
        _total = answerKey.length;
      });

      await _saveResult(script, score, answerKey.length, method: 'auto');
    } catch (e) {
      _showSnackBar("Auto-marking failed: $e", isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveManualScore(Map<String, dynamic> script) async {
    final score = int.tryParse(_manualController.text.trim());
    if (score == null || score < 0) {
      _showSnackBar("⚠ Enter a valid positive number", isError: true);
      return;
    }

    // Optional: You can set a maximum score limit if desired
    if (score > 100) {
      _showSnackBar("⚠ Score too high! Max is 100", isError: true);
      return;
    }

    await _saveResult(script, score, null, method: 'manual');
  }

  Future<void> _saveResult(Map<String, dynamic> script, int score, int? total,
      {required String method}) async {
    final id = script['id'];

    // Save to /results
    await FirebaseFirestore.instance.collection('results').add({
      'name': script['name'],
      'score': score,
      'total': total ?? 0,
      'method': method,
      'timestamp': Timestamp.now(),
    });

    // Update script status to 'marked'
    await FirebaseFirestore.instance.collection('scripts').doc(id).update({
      'status': 'marked',
      'score': score,
      'total': total,
      'method': method,
    });

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
    final script =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;

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
                  // Metadata
                  if (submissionTime != null)
                    Text(
                      "Submitted: ${submissionTime.toLocal()}",
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  const SizedBox(height: 12),

                  const Text(
                    "Extracted Script Text:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),

                  // OCR Text
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

                  // Auto mark
                  ElevatedButton.icon(
                    icon: const Icon(Icons.bolt),
                    label: const Text("Auto Mark"),
                    onPressed: () => _autoMark(script),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: Colors.blue,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Manual mark
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
                    onPressed: () => _saveManualScore(script),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                  ),

                  // Result preview
                  if (_score != null && _total != null) ...[
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        "Preview Score: $_score / $_total",
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}