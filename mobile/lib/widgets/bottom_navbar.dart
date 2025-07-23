<<<<<<< HEAD
// TODO Implement this library.
=======
import 'package:flutter/material.dart';

class AutoMarkBottomNav extends StatelessWidget {
  final int currentIndex;

  const AutoMarkBottomNav({super.key, required this.currentIndex});

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/upload');
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/result');
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/answer_key');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (index) => _onTap(context, index),
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.blue,
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: true,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.upload_file),
          label: 'Upload',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.bar_chart),
          label: 'Results',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.key),
          label: 'Answer Key',
        ),
      ],
    );
  }
}
>>>>>>> be07d0b3d698b8f01f972effe4e728a74bd4b207
