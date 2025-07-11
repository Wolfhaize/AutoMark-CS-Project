import 'package:flutter/material.dart';


class CustomDrawer extends StatelessWidget {
  const CustomDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ✅ Drawer Header (App logo or user info)
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue.shade100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset('assets/icons/bluetick.png', height: 40),
                  const SizedBox(height: 10),
                  const Text(
                    'AutoMark',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Smart Script Grading',
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ],
              ),
            ),

            // ✅ Navigation Options
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text("Profile"),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/profile'); // Optional
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text("History"),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/history'); // Optional
              },
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text("Downloads"),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/downloads'); // Optional
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () => Navigator.pushReplacementNamed(context, '/settings'),
            ),
            ListTile(
              leading: Icon(Icons.mark_chat_unread),
              title: Text('Unmarked Scripts'),
              onTap: () => Navigator.pushReplacementNamed(context, '/unmarked'),
            ),
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: const Text('Marked Scripts'),
              onTap: () => Navigator.pushNamed(context, '/marked_scripts'),
            ),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text("About"),
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'AutoMark',
                  applicationVersion: 'v1.0.0',
                  applicationIcon: Image.asset('assets/icons/bluetick.png', height: 40),
                  children: const [
                    Text("AutoMark automatically grades scanned exam scripts."),
                    SizedBox(height: 10),
                    Text("Developed by Group 27 - CS Project 2025"),
                  ],
                );
              },
            ),

            const Spacer(),

            // ✅ Optional Logout (can be reused)
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text("Logout", style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pushNamed(context, '/login'); // or show confirmation
              },
            ),
          ],
        ),
      ),
    );
  }
}