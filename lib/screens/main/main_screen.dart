import 'package:flutter/material.dart';
import '../feed/feed_screen.dart';
import '../upload/upload_screen.dart';
import '../profile/profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  static const TextStyle optionStyle = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.bold,
  );

  // Remove static list to allow proper state management for video feed
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    // Initialize screens here to ensure proper state management
    _screens = <Widget>[
      const FeedScreen(), // This will use the new fullscreen implementation
      const Center(child: Text('Discover', style: optionStyle)),
      const UploadScreen(),
      const Center(child: Text('Inbox', style: optionStyle)),
      const ProfileScreen(),
    ];
  }

  void _onItemTapped(int index) {
    if (index == 2) {
      // Upload button
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const UploadScreen()),
      );
      return;
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens.elementAt(_selectedIndex),
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          canvasColor: Colors.black,
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.black,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.grey,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search),
              label: 'Discover',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.add_box),
              label: 'Upload',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.inbox),
              label: 'Inbox',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
        ),
      ),
    );
  }
} 