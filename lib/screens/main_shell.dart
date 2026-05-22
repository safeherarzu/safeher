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
        bottomNavigationBar: _MainBottomNav(
          currentIndex: _index,
          mapLabel: context.t('map'),
          sosLabel: context.t('sosTitle'),
          profileLabel: context.t('profile'),
          onTap: (i) {
            FocusManager.instance.primaryFocus?.unfocus();
            SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
            setState(() => _index = i);
          },
        ),
      ),
    );
  }
}

/// Alt sekme çubuğu — ortada yükseltilmiş SOS, yanlarda Harita / Profil.
class _MainBottomNav extends StatelessWidget {
  const _MainBottomNav({
    required this.currentIndex,
    required this.mapLabel,
    required this.sosLabel,
    required this.profileLabel,
    required this.onTap,
  });

  final int currentIndex;
  final String mapLabel;
  final String sosLabel;
  final String profileLabel;
  final ValueChanged<int> onTap;

  static const _ink = Color(0xFF1E1038);
  static const _muted = Color(0xFF6B7280);
  static const _selectedFill = Color(0xFFEDE8FF);
  static const _selectedInk = Color(0xFF5C2FA8);
  static const _sosRed = Color(0xFFDC2626);
  static const _sosRedDark = Color(0xFFB91C1C);

  static const double _barHeight = 64;
  static const double _fabSize = 62;
  static const double _fabLift = 26;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final sosSelected = currentIndex == 1;

    return Padding(
      padding: EdgeInsets.fromLTRB(14, _fabLift + 4, 14, 8 + bottomPad),
      child: SizedBox(
        height: _barHeight + _fabLift,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Material(
              elevation: 14,
              shadowColor: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(24),
              color: Colors.white,
              child: SizedBox(
                height: _barHeight,
                child: Row(
                  children: [
                    _sideTab(
                      index: 0,
                      icon: Icons.map_rounded,
                      label: mapLabel,
                    ),
                    const SizedBox(width: _fabSize + 8),
                    _sideTab(
                      index: 2,
                      icon: Icons.person_rounded,
                      label: profileLabel,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 0,
              child: _SosFab(
                label: sosLabel,
                selected: sosSelected,
                onTap: () => onTap(1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sideTab({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final selected = currentIndex == index;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onTap(index),
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                decoration: BoxDecoration(
                  color: selected ? _selectedFill : null,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  size: 26,
                  color: selected ? _selectedInk : _muted,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? _selectedInk : _ink.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SosFab extends StatelessWidget {
  const _SosFab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          elevation: selected ? 16 : 12,
          shadowColor: _MainBottomNav._sosRed.withValues(alpha: 0.45),
          shape: const CircleBorder(),
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Ink(
              width: _MainBottomNav._fabSize,
              height: _MainBottomNav._fabSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: selected
                      ? [_MainBottomNav._sosRed, _MainBottomNav._sosRedDark]
                      : [
                          _MainBottomNav._sosRed.withValues(alpha: 0.92),
                          _MainBottomNav._sosRedDark,
                        ],
                ),
                border: Border.all(
                  color: Colors.white,
                  width: selected ? 3.5 : 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _MainBottomNav._sosRed.withValues(alpha: 0.35),
                    blurRadius: selected ? 14 : 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.sos_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: selected ? _MainBottomNav._sosRedDark : _MainBottomNav._ink,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}
