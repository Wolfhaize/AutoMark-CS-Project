import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/answer_entry.dart'; //  Model for structured answers
import '../utils/grading_logic.dart'; //  Custom grading logic

class ResultProvider with ChangeNotifier {
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;

  List<Map<String, dynamic>> get results => _results;
  bool get isLoading => _isLoading;

  double get averageScore {
    if (_results.isEmpty) return 0.0;

    final total = _results.fold<double>(
      0.0,
      (sum, r) => sum + ((r['score'] ?? 0) as num).toDouble(),
    );

    return total / _results.length;
  }

  int get totalSubmissions => _results.length;

  ///  Fetches results from Firestore
  Future<void> fetchResults() async {
    _isLoading = true;
    notifyListeners();

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('results')
          .orderBy('timestamp', descending: true)
          .get();

      _results = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unknown',
          'score': (data['score'] ?? 0) as num,
          'total': (data['total'] ?? 0) as num,
          'timestamp': data['timestamp'],
          'method': data['method'] ?? 'auto',
        };
      }).toList();
    } catch (e) {
      debugPrint('❌ Failed to fetch results: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  ///  Score using student & correct answers (Objective + Essay)
  void calculateScore(List<String> studentAnswers, List<AnswerEntry> correctAnswers) {
    final score = gradeAnswers(studentAnswers, correctAnswers);

    _results.insert(0, {
      'name': 'Anonymous', // You can override this when known
      'score': score,
      'total': correctAnswers.length,
      'timestamp': Timestamp.now(),
      'method': 'scan',
    });

    notifyListeners();
  }

  ///  Set a result directly when score is already calculated (e.g. AI/Auto)
  void setResult(int score, int total, {required String studentNumber, required String studentName}) {
    _results.insert(0, {
      'name': 'Anonymous',
      'score': score,
      'total': total,
      'timestamp': Timestamp.now(),
      'method': 'scan',
    });

    notifyListeners();
  }

  ///  Get result by student name
  Map<String, dynamic> getStudentResultByName(String name) {
    return _results.firstWhere(
      (r) => r['name'] == name,
      orElse: () => {'score': 0, 'total': 0},
    );
  }

  ///  Clear all stored results (used during reset)
  void clear() {
    _results.clear();
    notifyListeners();
  }
}