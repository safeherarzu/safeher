import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  static const _locationPromptKey = 'securityLocationPromptEnabled';
  static const _quickSosConfirmKey = 'securityQuickSosConfirmEnabled';

  bool _loading = true;
  bool _locationPromptEnabled = true;
  bool _quickSosConfirmEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _locationPromptEnabled = prefs.getBool(_locationPromptKey) ?? true;
      _quickSosConfirmEnabled = prefs.getBool(_quickSosConfirmKey) ?? true;
      _loading = false;
    });
  }

  Future<void> _setLocationPrompt(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_locationPromptKey, value);
    if (!mounted) return;
    setState(() => _locationPromptEnabled = value);
  }

  Future<void> _setQuickSosConfirm(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_quickSosConfirmKey, value);
    if (!mounted) return;
    setState(() => _quickSosConfirmEnabled = value);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.pageGradient),
      child: Scaffold(
        appBar: AppBar(title: Text(context.t('securitySettings'))),
        body: _loading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.t('securityPrivacyTitle'),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              context.t('locationReminders'),
                              style: TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              context.t('locationRemindersSubtitle'),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                            value: _locationPromptEnabled,
                            onChanged: _setLocationPrompt,
                          ),
                          const Divider(color: Colors.white24),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              context.t('quickSosConfirm'),
                              style: TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              context.t('quickSosConfirmSubtitle'),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                            value: _quickSosConfirmEnabled,
                            onChanged: _setQuickSosConfirm,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.info_outline, color: Colors.white),
                      title: Text(
                        context.t('note'),
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        context.t('sosSettingsHint'),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
