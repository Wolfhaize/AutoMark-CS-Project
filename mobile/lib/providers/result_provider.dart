import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ResultProvider with ChangeNotifier {
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;

  List<Map<String, dynamic>> get results => _results;
  bool get isLoading => _isLoading;

  double get averageScore {
    if (_results.isEmpty) return 0;
    final total = _results.fold(0, (sum, r) => sum + (r['score'] ?? 0));
    return total / _results.length;
  }

  int get totalSubmissions => _results.length;

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
          'score': data['score'] ?? 0,
          'total': data['total'] ?? 0,
          'timestamp': data['timestamp'],
          'method': data['method'] ?? 'auto',
        };
      }).toList();
    } catch (e) {
      print('❌ Failed to fetch results: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Map<String, dynamic> getStudentResultByName(String name) {
    return _results.firstWhere(
      (r) => r['name'] == name,
      orElse: () => {'score': 0, 'total': 0},
    );
  }

  void clear() {
    _results.clear();
    notifyListeners();
  }
}