import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/app_language_service.dart';
import 'about_app_screen.dart';
import 'account_screen.dart';
import 'security_settings_screen.dart';
import '../theme/app_theme.dart';

class SettingsMenuScreen extends StatelessWidget {
  const SettingsMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final languageService = AppLanguageService.instance;

    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.pageGradient),
      child: Scaffold(
        appBar: AppBar(title: Text(context.t('settings'))),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Column(
                children: [
                  ValueListenableBuilder<Locale>(
                    valueListenable: languageService.localeNotifier,
                    builder: (context, locale, child) {
                      return ListTile(
                        leading: const Icon(Icons.language, color: Colors.white),
                        title: Text(
                          context.t('language'),
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          languageService.selectedCode == 'system'
                              ? context.t('languageSystem')
                              : languageService.selectedCode == 'en'
                                  ? context.t('languageEnglish')
                                  : context.t('languageTurkish'),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.82),
                          ),
                        ),
                        trailing:
                            const Icon(Icons.chevron_right, color: Colors.white),
                        onTap: () async {
                          await showModalBottomSheet<void>(
                            context: context,
                            backgroundColor: const Color(0xFF1F1840),
                            shape: const RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.vertical(top: Radius.circular(18)),
                            ),
                            builder: (context) {
                              Widget languageItem({
                                required String code,
                                required String label,
                              }) {
                                final selected =
                                    languageService.selectedCode == code;
                                return ListTile(
                                  leading: Icon(
                                    selected
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_off,
                                    color: Colors.white,
                                  ),
                                  title: Text(
                                    label,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  onTap: () async {
                                    await languageService.setLanguageCode(code);
                                    if (context.mounted) Navigator.pop(context);
                                  },
                                );
                              }

                              return SafeArea(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    languageItem(
                                      code: 'system',
                                      label: context.t('languageSystem'),
                                    ),
                                    languageItem(
                                      code: 'tr',
                                      label: context.t('languageTurkish'),
                                    ),
                                    languageItem(
                                      code: 'en',
                                      label: context.t('languageEnglish'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                  const Divider(color: Colors.white24, height: 1),
                  ListTile(
                    leading: const Icon(Icons.account_circle, color: Colors.white),
                    title: Text(
                      context.t('account'),
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Colors.white),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AccountScreen()),
                      );
                    },
                  ),
                  const Divider(color: Colors.white24, height: 1),
                  ListTile(
                    leading: const Icon(Icons.shield, color: Colors.white),
                    title: Text(
                      context.t('securitySettings'),
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Colors.white),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SecuritySettingsScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(color: Colors.white24, height: 1),
                  ListTile(
                    leading: const Icon(Icons.info_outline, color: Colors.white),
                    title: Text(
                      context.t('aboutApp'),
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Colors.white),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AboutAppScreen()),
                      );
                    },
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
