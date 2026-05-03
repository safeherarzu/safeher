import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../l10n/app_strings.dart';
import 'home_map_screen.dart';
import 'profile_screen.dart';
import 'sos_screen.dart';
import '../theme/app_theme.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  final _pages = const [
    HomeMapScreen(),
    SosScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final titles = [
      context.t('map'),
      'SOS',
      context.t('profile'),
    ];

    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.pageGradient),
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: _pages,
        ),
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                'assets/branding/logo_mark_vector.svg',
                width: 26,
                height: 26,
              ),
              const SizedBox(width: 8),
              Text(
                titles[_index],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          centerTitle: true,
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: Colors.white.withValues(alpha: 0.14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: BottomNavigationBar(
              currentIndex: _index,
              onTap: (i) => setState(() => _index = i),
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: Colors.white,
              unselectedItemColor: Colors.white70,
              items: [
                BottomNavigationBarItem(
                  icon: Icon(Icons.map),
                  label: context.t('map'),
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.warning),
                  label: 'SOS',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: context.t('profile'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

