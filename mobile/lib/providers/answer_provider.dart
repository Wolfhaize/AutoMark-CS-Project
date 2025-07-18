import 'package:flutter/material.dart';

/// Model representing each answer in the key.
class AnswerEntry {
  final String type; // 'Objective', 'Keyword', or 'Essay'
  final String answer;
  final List<String> keywords;
  final double weight; // Defaults to 1.0
  final bool useAI;    // If true, only AI should grade this answer

  AnswerEntry({
    required this.type,
    this.answer = '',
    this.keywords = const [],
    this.weight = 1.0,
    this.useAI = false,
  });

  factory AnswerEntry.fromJson(Map<String, dynamic> json) {
    return AnswerEntry(
      type: json['type'],
      answer: json['answer'] ?? '',
      keywords: List<String>.from(json['keywords'] ?? []),
      weight: (json['weight'] is num) ? json['weight'].toDouble() : 1.0,
      useAI: json['useAI'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'answer': answer,
      'keywords': keywords,
      'weight': weight,
      'useAI': useAI,
    };
  }
}

class AnswerProvider extends ChangeNotifier {
  final List<AnswerEntry> _entries = [];

  List<AnswerEntry> get entries => List.unmodifiable(_entries);

  void loadFromJson(List<dynamic> jsonList) {
    _entries.clear();
    _entries.addAll(jsonList.map((e) => AnswerEntry.fromJson(e)));
    notifyListeners();
  }

  void addEntry(AnswerEntry entry) {
    _entries.add(entry);
    notifyListeners();
  }

  void removeEntry(int index) {
    if (index >= 0 && index < _entries.length) {
      _entries.removeAt(index);
      notifyListeners();
    }
  }

  void clear() {
    _entries.clear();
    notifyListeners();
  }

  List<Map<String, dynamic>> toJsonList() {
    return _entries.map((e) => e.toJson()).toList();
  }
}