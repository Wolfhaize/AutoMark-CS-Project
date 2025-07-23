import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import '../providers/dashboard_provider.dart';
import 'mark_script_screen.dart';
import 'answer_key_screen.dart';

class UnmarkedScriptsScreen extends StatefulWidget {
  const UnmarkedScriptsScreen({super.key});

  @override
  State<UnmarkedScriptsScreen> createState() => _UnmarkedScriptsScreenState();
}

class _UnmarkedScriptsScreenState extends State<UnmarkedScriptsScreen> {
  late Future<List<Map<String, dynamic>>> _futureScripts;
  List<dynamic> _selectedGuideAnswers = [];
  String? _selectedGuideTitle;

  @override
  void initState() {
    super.initState();
    _futureScripts = fetchUnmarkedScripts();
    _loadSelectedGuide();
  }

  Future<void> _loadSelectedGuide() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedGuideId = prefs.getString('selected_guide_id');

    if (selectedGuideId == null) {
      setState(() {
        _selectedGuideAnswers = [];
        _selectedGuideTitle = null;
      });
      return;
    }

    final doc = await FirebaseFirestore.instance
        .collection('answer_keys')
        .doc(selectedGuideId)
        .get();

    final data = doc.data();
    if (data != null && data['answers'] != null) {
      setState(() {
        _selectedGuideAnswers = data['answers'];
        _selectedGuideTitle = data['title'];
      });

      // Refresh dashboard stats when guide is changed
      Provider.of<DashboardProvider>(context, listen: false).fetchStats();
    } else {
      setState(() {
        _selectedGuideAnswers = [];
        _selectedGuideTitle = null;
      });
    }
  }

  Future<List<Map<String, dynamic>>> fetchUnmarkedScripts() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('scripts')
        .where('status', isEqualTo: 'unmarked')
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'name': data['name'] ?? 'Unnamed Student',
        'ocrText': data['ocrText'] ?? '',
        'timestamp': data['timestamp'],
      };
    }).toList();
  }

  String formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown';
    return DateFormat('MMM d, yyyy – hh:mm a').format(timestamp.toDate());
  }

  Future<void> _refresh() async {
    setState(() {
      _futureScripts = fetchUnmarkedScripts();
    });
    await _loadSelectedGuide();
    await Provider.of<DashboardProvider>(context, listen: false).fetchStats();
  }

  void _changeGuide() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AnswerKeyScreen()),
    ).then((_) => _loadSelectedGuide());
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _deleteAllScripts() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete All Scripts"),
        content: const Text("Are you sure you want to delete all unmarked scripts?"),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton(
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('scripts')
          .where('status', isEqualTo: 'unmarked')
          .get();

      final batch = FirebaseFirestore.instance.batch();

      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      _showSnackBar("✅ All unmarked scripts deleted.");

      setState(() {
        _futureScripts = fetchUnmarkedScripts();
      });

      await Provider.of<DashboardProvider>(context, listen: false).fetchStats();
    } catch (e) {
      _showSnackBar("Failed to delete scripts: $e", isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Unmarked Scripts"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: "Delete All Scripts",
            onPressed: _deleteAllScripts,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _futureScripts,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text("Error: ${snapshot.error}"));
            }

            final scripts = snapshot.data ?? [];

            if (scripts.isEmpty) {
              return const Center(child: Text("All scripts are marked."));
            }

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: scripts.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_selectedGuideTitle != null)
                        Container(
                          color: Colors.green.shade50,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.all(8),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Using: $_selectedGuideTitle",
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              TextButton(
                                onPressed: _changeGuide,
                                child: const Text("Change Guide"),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          color: Colors.amber.shade100,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.all(8),
                          child: Row(
                            children: [
                              const Icon(Icons.warning, color: Colors.orange),
                              const SizedBox(width: 8),
                              const Expanded(child: Text("No marking guide selected.")),
                              TextButton(
                                onPressed: _changeGuide,
                                child: const Text("Select Guide"),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                }

                final script = scripts[index - 1];
                final preview = script['ocrText'] ?? '';
                final docId = script['id'];
                final timestamp = script['timestamp'] as Timestamp?;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.description_outlined, color: Colors.grey),
                          title: Text(script['name'] ?? 'Student'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 6),
                              Text(
                                preview.length > 100 ? '${preview.substring(0, 100)}...' : preview,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "Uploaded: ${formatTimestamp(timestamp)}",
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text("Mark"),
                          onPressed: _selectedGuideAnswers.isEmpty
                              ? () => _showSnackBar("⚠ Please select a guide first", isError: true)
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => MarkScriptScreen(
                                        script: script,
                                        guideAnswers: _selectedGuideAnswers,
                                      ),
                                    ),
                                  ).then((_) => _refresh());
                                },
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
