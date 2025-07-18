import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardProvider extends ChangeNotifier {
  int marked = 0;
  int unmarked = 0;
  int total = 0;
  bool answerKeyAvailable = false;

  bool isLoading = false; // Optional: For loading states

  Future<void> fetchStats() async {
    try {
      isLoading = true;
      notifyListeners();

      final scriptsSnapshot = await FirebaseFirestore.instance.collection('scripts').get();
      marked = scriptsSnapshot.docs.where((doc) => doc['status'] == 'marked').length;
      unmarked = scriptsSnapshot.docs.where((doc) => doc['status'] == 'unmarked').length;
      total = scriptsSnapshot.docs.length;

      final answerKeySnapshot = await FirebaseFirestore.instance
          .collection('answer_key')
          .doc('latest')
          .get();

      answerKeyAvailable = answerKeySnapshot.exists;
    } catch (e) {
      print("Error fetching dashboard stats: $e");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // Optional: Clear stats if you need a reset
  void clearStats() {
    marked = 0;
    unmarked = 0;
    total = 0;
    answerKeyAvailable = false;
    notifyListeners();
  }
}
