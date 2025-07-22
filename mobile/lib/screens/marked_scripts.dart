import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/dashboard_provider.dart';
import '../widgets/bottom_navbar.dart';
import '../widgets/custom_drawer.dart';

class MarkedScriptsScreen extends StatefulWidget {
  const MarkedScriptsScreen({super.key});

  @override
  State<MarkedScriptsScreen> createState() => _MarkedScriptsScreenState();
}

class _MarkedScriptsScreenState extends State<MarkedScriptsScreen> {
  late Stream<QuerySnapshot> _markedScriptsStream;

  @override
  void initState() {
    super.initState();
    _loadScripts();
  }

  void _loadScripts() {
    _markedScriptsStream = FirebaseFirestore.instance
        .collection('scripts')
        .where('status', isEqualTo: 'marked')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> _refresh() async {
    setState(() => _loadScripts());
    await Provider.of<DashboardProvider>(context, listen: false).fetchStats();
  }

  String formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown time';
    return DateFormat('MMM d, yyyy – hh:mm a').format(timestamp.toDate());
  }

  Color getMethodColor(String method) {
    switch (method.toLowerCase()) {
      case 'ai':
        return Colors.deepPurple;
      case 'auto':
        return Colors.blue;
      default:
        return Colors.green;
    }
  }

  Future<void> _deleteScript(BuildContext context, String docId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Script"),
        content: const Text("Are you sure you want to delete this marked script?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete")),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseFirestore.instance.collection('scripts').doc(docId).delete();

      // ✅ Refresh the dashboard stats after deletion
      await Provider.of<DashboardProvider>(context, listen: false).fetchStats();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Script deleted.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Marked Scripts"),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      drawer: const CustomDrawer(),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: StreamBuilder<QuerySnapshot>(
          stream: _markedScriptsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return const Center(child: Text("🎯 No scripts marked yet."));
            }

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data() as Map<String, dynamic>;

                final name = data['name'] ?? 'Unnamed';
                final score = data['score'] ?? 0;
                final total = data['total'] ?? '?';
                final method = data['method'] ?? 'manual';
                final timestamp = data['timestamp'] as Timestamp?;
                final feedback = data['feedback'];

                return Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.check_circle, color: Colors.green),
                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Score: $score / $total"),
                              Text(
                                "Method: ${method.toUpperCase()}",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: getMethodColor(method),
                                ),
                              ),
                              Text(
                                "Marked: ${formatTimestamp(timestamp)}",
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _deleteScript(context, doc.id),
                            tooltip: "Delete",
                          ),
                        ),
                        if (feedback != null && feedback.toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0, left: 8.0, right: 8.0),
                            child: Text(
                              "🧠 AI Feedback: $feedback",
                              style: const TextStyle(
                                color: Colors.black87,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
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
      bottomNavigationBar: const AutoMarkBottomNav(currentIndex: 3),
    );
  }
}
