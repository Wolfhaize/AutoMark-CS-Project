import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/bottom_navbar.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'AutoMark',
      applicationVersion: 'v1.0.0',
      applicationIcon: Image.asset('assets/icons/bluetick.png', height: 40),
      children: const [
        Text('AutoMark helps automatically grade scanned exam scripts.'),
        SizedBox(height: 10),
        Text('Developed by: Group 27 - CS Project 2025'),
      ],
    );
  }

  void _changePassword(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: user.email!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password reset link sent to your email")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userEmail = FirebaseAuth.instance.currentUser?.email ?? 'Unknown';

    return Scaffold(
      appBar: AppBar(
        title: const Text("SETTINGS"),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Account',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          ListTile(
            leading: Image.asset('assets/icons/email.png', height: 24),
            title: const Text("Email"),
            subtitle: Text(userEmail),
          ),

          ListTile(
            leading: Image.asset('assets/icons/lock.png', height: 24),
            title: const Text("Change Password"),
            onTap: () => _changePassword(context),
          ),

          ListTile(
            leading: Image.asset('assets/icons/info.png', height: 24),
            title: const Text("About AutoMark"),
            onTap: () => _showAboutDialog(context),
          ),

          ListTile(
            leading: Image.asset('assets/icons/logout.png', height: 24),
            title: const Text("Logout", style: TextStyle(color: Colors.red)),
            onTap: () => _signOut(context),
          ),
        ],
      ),

      bottomNavigationBar: const AutoMarkBottomNav(currentIndex: 4),
    );
  }
}