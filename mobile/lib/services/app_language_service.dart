import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLanguageService {
  AppLanguageService._();
  static final AppLanguageService instance = AppLanguageService._();

  static const _languageCodeKey = 'appLanguageCode';
  // system | tr | en
  String _selectedCode = 'system';

  final ValueNotifier<Locale> localeNotifier =
      ValueNotifier<Locale>(const Locale('tr'));

  String get selectedCode => _selectedCode;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedCode = prefs.getString(_languageCodeKey) ?? 'system';
    localeNotifier.value = _resolveLocale(_selectedCode);
  }

  Future<void> setLanguageCode(String code) async {
    _selectedCode = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageCodeKey, code);
    localeNotifier.value = _resolveLocale(code);
  }

  Locale _resolveLocale(String code) {
    if (code == 'tr') return const Locale('tr');
    if (code == 'en') return const Locale('en');

    final systemCode = ui.PlatformDispatcher.instance.locale.languageCode;
    if (systemCode.toLowerCase().startsWith('en')) return const Locale('en');
    return const Locale('tr');
  }
}
