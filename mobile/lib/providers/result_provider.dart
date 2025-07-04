import 'package:flutter/material.dart';

class GradeResult{
  final String studentId;
  final List<String>studentAnswers;
  final double score;

  GradeResult({
    required this.studentId,
    required this.studentAnswers,
    required this.score,
  });
}

class ResultProvider extends ChangeNotifier {
  List<GradeResult> _results = [];
  
  //Getter
  List<GradeResult> get results => _results;

  //Add a new result
  void addResult(GradeResult result){
    _results.add(result);
    notifyListeners();
  }
  //clear all Results
  void clearResults(){
    _results.clear();
    notifyListeners();
  }

  //get result by Id
  GradeResult? getResultById(String id){
    try{
      return _results.firstWhere((res) => res.studentId == id);
    } catch (e){
      return null;
    }
  }
}