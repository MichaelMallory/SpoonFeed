import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../feed/feed_screen.dart';
import '../discover/discover_screen.dart';
import '../upload/upload_screen.dart';
import '../profile/profile_screen.dart';
import '../cookbook/cookbook_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final _auth = FirebaseAuth.instance;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = <Widget>[
      const FeedScreen(),
      const DiscoverScreen(),
      const UploadScreen(),
      const CookbookScreen(),
      ProfileScreen(userId: _auth.currentUser?.uid ?? ''),
    ];
  }

  void _onItemTapped(int index) async {
    if (index == 2) {
      // Upload button
      final result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(builder: (context) => const UploadScreen()),
      );
      
      // If upload was successful and profile needs refresh
      if (result != null && result['refresh'] == true) {
        if (!mounted) return;
        
        // Only refresh the profile screen
        setState(() {
          _screens[4] = ProfileScreen(userId: _auth.currentUser?.uid ?? '');
          _selectedIndex = 4;
        });
      }
      return;
    }
    
    if (mounted) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    print('[MainScreen] Building main screen');
    return Scaffold(
      extendBody: true, // Allow content to go behind bottom nav
      resizeToAvoidBottomInset: false,
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.5),
              Colors.black,
            ],
          ),
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.grey,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedFontSize: 10,
          unselectedFontSize: 10,
          iconSize: 24,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
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
              icon: Icon(Icons.add_circle_outline),
              label: 'Upload',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.book),
              label: 'Cookbook',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
} 