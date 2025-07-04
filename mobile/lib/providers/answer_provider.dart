import 'package:flutter/material.dart';

class AnswerProvider extends ChangeNotifier{
  List<String> _answerKey = [];

  //Getter
  List<String> get answerKey => _answerKey;

  //set new answer key
  void setAnswerKey(List<String> newKey){
    _answerKey = newKey;
    notifyListeners();//Tells the UI to Update
  }

  //Clear all answers
  void clearAnswerKey(){
    _answerKey.clear();
    notifyListeners();
  }
  // add a single answer
  void addAnswer(String answer){
    _answerKey.add(answer);
    notifyListeners();
  }

  //remove answer by index
  void removeAnswer(int index){
    _answerKey.remove(index);
    notifyListeners();
  }
}