import 'package:flutter/material.dart';
import 'map_page.dart';
import 'profile_page.dart';
import 'sos_page.dart';
import 'notifications_page.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;
  final double? focusLat;
  final double? focusLng;

  const MainScreen({
    super.key,
    this.initialIndex = 0,
    this.focusLat,
    this.focusLng,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {

  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {

    final pages = [
      MapPage(
        focusLat: widget.focusLat,
        focusLng: widget.focusLng,
      ),
      const SosPage(),
      const NotificationsPage(),
      ProfilePage(),
    ];

    final titles = [
      "Harita",
      "SOS",
      "Bildirimler",
      "Profil",
    ];

    return Scaffold(

      /// APP BAR
      appBar: AppBar(
        title: Text(titles[_currentIndex]),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 1,
      ),

      /// BODY
      body: pages[_currentIndex],

      /// NAVIGATION
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [

          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: "Harita",
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.warning),
            label: "SOS",
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: "Bildirim",
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: "Profil",
          ),
        ],
      ),
    );
  }
}