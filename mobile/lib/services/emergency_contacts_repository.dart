import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class EmergencyContactsRepository {
  EmergencyContactsRepository({this.prefs});

  final SharedPreferences? prefs;
  static const _key = 'emergency_contacts';

  Future<SharedPreferences> _getPrefs() async {
    return prefs ?? await SharedPreferences.getInstance();
  }

  Future<List<String>> getAll() async {
    final p = await _getPrefs();
    final raw = p.getString(_key);
    if (raw == null || raw.isEmpty) return const [];

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.map((e) => e.toString()).toList();
  }

  Future<void> add(String phone) async {
    final normalized = normalizePhone(phone);
    if (normalized.isEmpty) return;

    final p = await _getPrefs();
    final current = await getAll();
    if (current.contains(normalized)) return;
    final next = [...current, normalized];
    p.setString(_key, jsonEncode(next));
  }

  Future<void> remove(String phone) async {
    final normalized = normalizePhone(phone);
    if (normalized.isEmpty) return;

    final p = await _getPrefs();
    final current = await getAll();
    final next = current.where((e) => e != normalized).toList();
    p.setString(_key, jsonEncode(next));
  }

  /// WhatsApp `wa.me/<phone>` formatı için sadece rakam bırakır.
  static String normalizePhone(String input) {
    final digitsOnly = input.replaceAll(RegExp(r'[^0-9]'), '');
    return digitsOnly;
  }
}

