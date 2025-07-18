import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile/models/answer_entry.dart';

class MarkingGuide {
  final String id;
  final String title;
  final List<Map<String, dynamic>> entries;

  MarkingGuide({
    required this.id,
    required this.title,
    required this.entries,
  });

  factory MarkingGuide.fromJson(String id, Map<String, dynamic> json) {
    final answers = List<Map<String, dynamic>>.from(json['answers'] ?? []);
    return MarkingGuide(
      id: id,
      title: json['title'] ?? 'Untitled',
      entries: answers,
    );
  }
}

class MarkingGuideProvider with ChangeNotifier {
  List<MarkingGuide> _allGuides = [];
  MarkingGuide? _selectedGuide;

  List<MarkingGuide> get allGuides => _allGuides;
  MarkingGuide? get selectedGuide => _selectedGuide;

  /// Loads all guides from Firebase
  Future<void> fetchGuides() async {
    final snapshot = await FirebaseFirestore.instance.collection('answer_key').get();
    _allGuides = snapshot.docs.map((doc) {
      return MarkingGuide.fromJson(doc.id, doc.data());
    }).toList();
    notifyListeners();
  }

  /// Select a guide to use for marking
  void setSelectedGuide(MarkingGuide guide) {
    _selectedGuide = guide;
    notifyListeners();
  }

  /// Clear the selection
  void clearSelection() {
    _selectedGuide = null;
    notifyListeners();
  }

  /// Find guide by ID (optional helper)
  MarkingGuide? getGuideById(String id) {
    return _allGuides.firstWhere((g) => g.id == id, orElse: () => _allGuides.first);
  }
}