import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final nameController = TextEditingController();
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    nameController.text = user?.displayName ?? '';
  }

  Future<void> _updateDisplayName() async {
    final newName = nameController.text.trim();
    if (newName.isEmpty || user == null) return;

    setState(() => isSaving = true);

    try {
      // Update FirebaseAuth profile
      await user!.updateDisplayName(newName);
      await user!.reload();
      // Update Firestore profile (optional)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .set({'displayName': newName}, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("No user logged in.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.account_circle, size: 80, color: Colors.grey),
            const SizedBox(height: 20),
            Text(user!.email ?? "No Email"),
            const SizedBox(height: 10),
            Text("User ID: ${user!.uid}", style: const TextStyle(fontSize: 12)),
            const Divider(height: 30),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "Display Name",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            isSaving
                ? const CircularProgressIndicator()
                : ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    onPressed: _updateDisplayName,
                    label: const Text("Save Changes"),
                  ),
            const Spacer(),
            ElevatedButton.icon(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
              label: const Text("Back to Home"),
            ),
          ],
        ),
      ),
    );
  }
}
