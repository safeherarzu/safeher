import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../l10n/app_strings.dart';
import '../models/map_pin_visibility.dart';
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

  /// Profil → harita: hangi pinler vurgulansın (her atamada yeni [token] ile tetiklenir).
  final ValueNotifier<MapPinFilterIntent?> _mapPinIntent = ValueNotifier(null);

  /// Keep one instance per tab once built; defer SOS/profile until first opened.
  final List<Widget?> _pages = [null, null, null];

  @override
  void dispose() {
    _mapPinIntent.dispose();
    super.dispose();
  }

  void _openMapWithPinFilter(MapPinVisibilityFilter filter) {
    setState(() => _index = 0);
    _mapPinIntent.value = MapPinFilterIntent(
      filter,
      DateTime.now().microsecondsSinceEpoch,
    );
  }

  Widget _tabSlot(int i, Widget Function() create) {
    if (_pages[i] != null) return _pages[i]!;
    if (i != _index) return const SizedBox.shrink();
    final w = create();
    _pages[i] = w;
    return w;
  }

  @override
  Widget build(BuildContext context) {
    final titles = [
      context.t('map'),
      context.t('sosTitle'),
      context.t('profile'),
    ];

    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.pageGradient),
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          sizing: StackFit.expand,
          children: [
            _tabSlot(
              0,
              () => HomeMapScreen(mapPinIntentListenable: _mapPinIntent),
            ),
            _tabSlot(1, () => SosScreen(visible: _index == 1)),
            _tabSlot(
              2,
              () => ProfileScreen(onOpenMapWithPinFilter: _openMapWithPinFilter),
            ),
          ],
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
              onTap: (i) {
                FocusManager.instance.primaryFocus?.unfocus();
                SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
                setState(() => _index = i);
              },
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
                  label: context.t('sosTitle'),
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
