import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../widgets/bottom_navbar.dart';
import '../widgets/custom_drawer.dart';
import '../utils/pdf_generator.dart';
import '../providers/dashboard_provider.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final List<QueryDocumentSnapshot> _results = [];
  DocumentSnapshot? _lastDocument;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  final int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _loadInitialResults();
  }

  double calculateAverage(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) return 0;
    final total = docs.fold(0, (sum, doc) => sum + (doc['score'] as int));
    return total / docs.length;
  }

  Future<void> _loadInitialResults() async {
    setState(() {
      _results.clear();
      _lastDocument = null;
      _hasMore = true;
    });
    await _fetchResults();
  }

  Future<void> _fetchResults() async {
    if (!_hasMore) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() => _isLoadingMore = true);

    Query query = FirebaseFirestore.instance
        .collection('results')
        .where('userId', isEqualTo: currentUser.uid)
        .orderBy('timestamp', descending: true)
        .limit(_pageSize);

    if (_lastDocument != null) {
      query = query.startAfterDocument(_lastDocument!);
    }

    final snapshot = await query.get();

    if (snapshot.docs.isNotEmpty) {
      _lastDocument = snapshot.docs.last;
      _results.addAll(snapshot.docs);
    }

    if (snapshot.docs.length < _pageSize) {
      _hasMore = false;
    }

    setState(() => _isLoadingMore = false);
  }

  Future<void> _generateReport() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating PDF report...')),
      );

      final snapshot = await FirebaseFirestore.instance
          .collection('results')
          .where('userId', isEqualTo: currentUser.uid)
          .orderBy('timestamp', descending: true)
          .get();

      final docs = snapshot.docs;

      if (docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No data to generate report.')),
        );
        return;
      }

      await PDFGenerator.generateAndPrintReport(docs);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF report generated and saved successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate report: $e')),
      );
    }
  }

  Future<void> _deleteSingleResult(String docId) async {
  try {
    final docSnapshot = await FirebaseFirestore.instance.collection('results').doc(docId).get();

    if (!docSnapshot.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Result not found.')),
      );
      return;
    }

    final data = docSnapshot.data()!;

    // Prepare history entry
    final historyData = {
      ...data,
      'deletedAt': Timestamp.now(),
      'originalId': docId,
      'status': 'deleted',
      'type': 'result', // Optional: to distinguish results from scripts
    };

    // Save to history first
    await FirebaseFirestore.instance.collection('history').doc(docId).set(historyData);

    // Delete from original collection
    await FirebaseFirestore.instance.collection('results').doc(docId).delete();

    setState(() {
      _results.removeWhere((doc) => doc.id == docId);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Result moved to history.')),
    );

    await Provider.of<DashboardProvider>(context, listen: false).fetchStats();
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('❌ Failed to delete result: $e')),
    );
  }
}
  @override
  Widget build(BuildContext context) {
    final avgScore = calculateAverage(_results).toStringAsFixed(1);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Results & Insights"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export Summary',
            onPressed: _generateReport,
          ),
        ],
      ),
      drawer: const CustomDrawer(),
      body: _results.isEmpty
          ? _isLoadingMore
              ? const Center(child: CircularProgressIndicator())
              : const Center(child: Text("No results available yet."))
          : RefreshIndicator(
              onRefresh: _loadInitialResults,
              child: ListView.builder(
                itemCount: _results.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildSummaryHeader(avgScore);
                  }

                  if (_hasMore && index == _results.length) {
                    _fetchResults();
                    return const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final doc = _results[index - 1];
                  return _buildResultCard(doc);
                },
              ),
            ),
      bottomNavigationBar: const AutoMarkBottomNav(currentIndex: 2),
    );
  }

  Widget _buildSummaryHeader(String avgScore) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Class Performance",
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text("Average Score: $avgScore%", style: const TextStyle(fontWeight: FontWeight.w600)),
          const Divider(height: 30),
          const Text("Student Scores", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildResultCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final name = data['name'] ?? 'Unnamed';
    final score = data['score'] ?? 0;
    final method = data['method'] ?? 'manual';
    final feedback = data['feedback'] ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
        color: Colors.grey.shade100,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text("Method: ${method.toUpperCase()}",
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                if (feedback.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text("Feedback: $feedback",
                      style: const TextStyle(fontSize: 12, color: Colors.black87)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              Text("$score%",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _deleteSingleResult(doc.id),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
