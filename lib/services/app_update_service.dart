import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_strings.dart';

/// Mağaza / Firestore üzerinden sürüm kontrolü ve güncelleme diyaloğu.
class AppUpdateService {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  static const _bundleId = 'com.safeher.womensafety';
  static const _playStoreUrl =
      'https://play.google.com/store/apps/details?id=$_bundleId';

  /// Firestore: `app_config/store` — yayın sonrası min sürümü buradan güncelleyebilirsiniz.
  /// Örnek alanlar: min_version_ios, min_version_android, message_tr, message_en, force_update
  static const _firestoreDoc = 'app_config/store';

  Future<void> maybeShowUpdateDialog(BuildContext context) async {
    if (kIsWeb) return;

    try {
      final info = await PackageInfo.fromPlatform();
      final current = info.version;
      final update = await _resolveUpdateTarget();
      if (update == null) return;
      if (!_isOlder(current, update.version)) return;
      if (!context.mounted) return;

      await _showDialog(
        context,
        storeVersion: update.version,
        storeUrl: update.storeUrl,
        message: update.message,
        forceUpdate: update.forceUpdate,
      );
    } catch (e, st) {
      debugPrint('AppUpdateService: $e\n$st');
    }
  }

  Future<_UpdateTarget?> _resolveUpdateTarget() async {
    final fromFirestore = await _fromFirestore();
    if (fromFirestore != null) return fromFirestore;

    if (Platform.isIOS) {
      return _fromItunes();
    }
    if (Platform.isAndroid) {
      return _fromPlayListing();
    }
    return null;
  }

  Future<_UpdateTarget?> _fromFirestore() async {
    try {
      final snap =
          await FirebaseFirestore.instance.doc(_firestoreDoc).get();
      if (!snap.exists) return null;
      final data = snap.data();
      if (data == null) return null;

      final isIos = Platform.isIOS;
      final minKey = isIos ? 'min_version_ios' : 'min_version_android';
      final latestKey = isIos ? 'latest_version_ios' : 'latest_version_android';
      final version = (data[latestKey] ?? data[minKey] ?? data['min_version'])
          ?.toString()
          .trim();
      if (version == null || version.isEmpty) return null;

      final lang = Platform.localeName.startsWith('tr') ? 'tr' : 'en';
      final msgKey = lang == 'tr' ? 'message_tr' : 'message_en';
      final message = data[msgKey]?.toString();

      final storeUrl = (isIos
              ? data['ios_store_url'] ?? data['store_url_ios']
              : data['android_store_url'] ?? data['store_url_android'])
          ?.toString();

      final resolvedUrl = (storeUrl != null && storeUrl.isNotEmpty)
          ? storeUrl
          : (isIos ? await _itunesTrackUrl() : null);
      return _UpdateTarget(
        version: version,
        storeUrl: resolvedUrl ?? _playStoreUrl,
        message: message,
        forceUpdate: data['force_update'] == true,
      );
    } catch (e) {
      debugPrint('Firestore app_config: $e');
      return null;
    }
  }

  Future<_UpdateTarget?> _fromItunes() async {
    final version = await _itunesVersion();
    if (version == null) return null;
    final url = await _itunesTrackUrl();
    return _UpdateTarget(
      version: version,
      storeUrl: url ?? _playStoreUrl,
      forceUpdate: false,
    );
  }

  Future<_UpdateTarget?> _fromPlayListing() async {
    // Play Store resmi basit API vermez; Firestore yoksa yalnızca mağaza linki.
    return null;
  }

  Future<String?> _itunesVersion() async {
    final uri = Uri.parse(
      'https://itunes.apple.com/lookup?bundleId=$_bundleId&country=tr',
    );
    final res = await http
        .get(uri)
        .timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) return null;
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final results = json['results'] as List<dynamic>?;
    if (results == null || results.isEmpty) return null;
    final first = results.first as Map<String, dynamic>;
    return first['version']?.toString();
  }

  Future<String?> _itunesTrackUrl() async {
    final uri = Uri.parse(
      'https://itunes.apple.com/lookup?bundleId=$_bundleId&country=tr',
    );
    final res = await http
        .get(uri)
        .timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) return null;
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final results = json['results'] as List<dynamic>?;
    if (results == null || results.isEmpty) return null;
    final first = results.first as Map<String, dynamic>;
    return first['trackViewUrl']?.toString();
  }

  bool _isOlder(String current, String store) {
    return _compareVersions(current, store) < 0;
  }

  int _compareVersions(String a, String b) {
    final pa = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final pb = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final len = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < len; i++) {
      final va = i < pa.length ? pa[i] : 0;
      final vb = i < pb.length ? pb[i] : 0;
      if (va != vb) return va.compareTo(vb);
    }
    return 0;
  }

  Future<void> _showDialog(
    BuildContext context, {
    required String storeVersion,
    required String storeUrl,
    String? message,
    required bool forceUpdate,
  }) async {
    final title = context.t('updateAvailableTitle');
    final body = message?.isNotEmpty == true
        ? message!
        : context.tReplace('updateAvailableBody', {'version': storeVersion});

    await showDialog<void>(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (ctx) {
        return PopScope(
          canPop: !forceUpdate,
          child: AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              if (!forceUpdate)
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(context.t('updateLater')),
                ),
              FilledButton(
                onPressed: () async {
                  final uri = Uri.parse(storeUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                  if (!forceUpdate && ctx.mounted) Navigator.pop(ctx);
                },
                child: Text(context.t('updateNow')),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _UpdateTarget {
  const _UpdateTarget({
    required this.version,
    required this.storeUrl,
    this.message,
    this.forceUpdate = false,
  });

  final String version;
  final String storeUrl;
  final String? message;
  final bool forceUpdate;
}
