import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import 'auth_screen.dart';
import 'main_shell.dart';

class StartupFlow extends StatefulWidget {
  const StartupFlow({super.key});

  @override
  State<StartupFlow> createState() => _StartupFlowState();
}

class _StartupFlowState extends State<StartupFlow> {
  static const _seenOnboardingKey = 'seenOnboarding';
  static const _kvkkAcceptedKey = 'kvkkAccepted';
  static const _rememberMeKey = 'rememberMe';

  bool _showSplash = true;
  bool _seenOnboarding = false;
  bool _kvkkAccepted = false;
  final PageController _pageController = PageController();
  int _pageIndex = 0;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    _seenOnboarding = prefs.getBool(_seenOnboardingKey) ?? false;
    _kvkkAccepted = prefs.getBool(_kvkkAcceptedKey) ?? false;
    final rememberMe = prefs.getBool(_rememberMeKey) ?? true;
    if (!rememberMe && FirebaseAuth.instance.currentUser != null) {
      await FirebaseAuth.instance.signOut();
    }

    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    setState(() => _showSplash = false);
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenOnboardingKey, true);
    if (!mounted) return;
    setState(() => _seenOnboarding = true);
  }

  Future<void> _acceptKvkk() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kvkkAcceptedKey, true);
    if (!mounted) return;
    setState(() => _kvkkAccepted = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) return const _SplashView();
    if (!_kvkkAccepted) return _KvkkConsentView(onAccept: _acceptKvkk);
    if (_seenOnboarding) return const _AuthGateView();
    return _OnboardingView(
      controller: _pageController,
      pageIndex: _pageIndex,
      onPageChanged: (i) => setState(() => _pageIndex = i),
      onDone: _completeOnboarding,
    );
  }
}

class _KvkkConsentView extends StatefulWidget {
  const _KvkkConsentView({required this.onAccept});

  final Future<void> Function() onAccept;

  @override
  State<_KvkkConsentView> createState() => _KvkkConsentViewState();
}

class _KvkkConsentViewState extends State<_KvkkConsentView> {
  bool _checked = false;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.pageGradient),
      child: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'KVKK Aydınlatma ve Açık Rıza',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'SafeHer uygulamasında konum ve hesap verileri güvenlik amacıyla işlenir. '
                      'Devam ederek KVKK aydınlatma metnini okuduğunu ve kabul ettiğini onaylarsın.',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      value: _checked,
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppTheme.brandPink,
                      title: const Text(
                        'KVKK metnini okudum, kabul ediyorum.',
                        style: TextStyle(color: Colors.white),
                      ),
                      onChanged: _busy ? null : (v) => setState(() => _checked = v ?? false),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: (!_checked || _busy)
                          ? null
                          : () async {
                              setState(() => _busy = true);
                              await widget.onAccept();
                              if (mounted) setState(() => _busy = false);
                            },
                      child: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Devam Et'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthGateView extends StatelessWidget {
  const _AuthGateView();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null) return const AuthScreen();
        return const MainShell();
      },
    );
  }
}

class _SplashView extends StatelessWidget {
  const _SplashView();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.pageGradient),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SvgPicture.asset(
            'assets/branding/logo_full_vector.svg',
            width: 260,
          ),
        ),
      ),
    );
  }
}

class _OnboardingView extends StatelessWidget {
  const _OnboardingView({
    required this.controller,
    required this.pageIndex,
    required this.onPageChanged,
    required this.onDone,
  });

  final PageController controller;
  final int pageIndex;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    const imageSlides = [
      'assets/onboarding/onboarding2.png',
      'assets/onboarding/onboarding3.png',
    ];
    const pageCount = 3;

    final isLast = pageIndex == pageCount - 1;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: controller,
              itemCount: pageCount,
              onPageChanged: onPageChanged,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _OnboardingIntroSlide(hostContext: context);
                }
                final asset = imageSlides[index - 1];
                return SizedBox.expand(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRect(
                        child: Align(
                          alignment: Alignment.topCenter,
                          heightFactor: 0.9,
                          child: Image.asset(
                            asset,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              height: 220,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.24),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            Positioned(
              top: 8,
              right: 12,
              child: TextButton(
                onPressed: onDone,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.black.withValues(alpha: 0.25),
                ),
                child: Text(context.t('skip')),
              ),
            ),
            Positioned(
            left: 24,
            right: 24,
            bottom: 26,
            child: Column(
              children: [
                if (isLast)
                  SizedBox(
                    width: double.infinity,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: AppTheme.actionGradient,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: ElevatedButton(
                        onPressed: onDone,
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        child: Text(context.t('enterApp')),
                      ),
                    ),
                  )
                else
                  Text(
                    context.t('swipeToContinue'),
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.95)),
                  ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    pageCount,
                    (i) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == pageIndex ? 18 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == pageIndex
                            ? AppTheme.brandPink
                            : Colors.white.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ],
        ),
      ),
    );
  }
}

/// İlk slayt: tam ekran PNG yerine marka + metin (AI stok görsel yok).
class _OnboardingIntroSlide extends StatelessWidget {
  const _OnboardingIntroSlide({required this.hostContext});

  final BuildContext hostContext;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(gradient: AppTheme.pageGradient),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
        child: Column(
          children: [
            const Spacer(flex: 2),
            SvgPicture.asset(
              'assets/branding/logo_full_vector.svg',
              width: 240,
            ),
            const Spacer(),
            Text(
              hostContext.t('onboarding1Title'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              hostContext.t('onboarding1Subtitle'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 16,
                height: 1.45,
              ),
            ),
            const Spacer(flex: 3),
          ],
        ),
      ),
    );
  }
}
