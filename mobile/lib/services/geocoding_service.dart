import 'dart:convert';

import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class GeocodingService {
  Future<LatLng> geocodeAddress(
    String address, {
    String? localityHint,
    String? adminHint,
  }) async {
    final query = address.trim();
    if (query.isEmpty) {
      throw ArgumentError('Address boş olamaz.');
    }

    final fallback = _normalizeTurkish(query);
    final variants = _queryVariants(query);
    final hintParts = <String>[
      if ((localityHint ?? '').trim().isNotEmpty) localityHint!.trim(),
      if ((adminHint ?? '').trim().isNotEmpty) adminHint!.trim(),
    ];

    final hintedVariants = <String>[
      for (final v in variants)
        if (hintParts.isNotEmpty) '$v, ${hintParts.join(', ')}',
    ];

    final candidates = <String>[
      ...hintedVariants,
      ...variants,
      if (fallback != query) fallback,
      if (fallback != query) '$fallback, Turkiye',
      if (fallback != query) '$fallback, Turkey',
      '$query, Türkiye',
      '$query, Turkey',
    ];

    // Deterministic city fallbacks for common searches.
    final direct = _directCityFallback(query);
    if (direct != null) return direct;

    // Primary: Nominatim (more reliable for TR characters/addresses).
    for (final c in candidates) {
      final fromNominatim = await _fromNominatim(c);
      if (fromNominatim != null) return fromNominatim;
    }

    // Secondary: platform geocoder.
    for (final c in candidates) {
      try {
        final locations = await locationFromAddress(c);
        if (locations.isNotEmpty) {
          final first = locations.first;
          return LatLng(first.latitude, first.longitude);
        }
      } catch (_) {
        // Try next candidate.
      }
    }

    throw StateError('Adres bulunamadı.');
  }

  LatLng? _directCityFallback(String query) {
    final n = _normalizeTurkish(query).toLowerCase();
    if (n == 'izmir' || n.contains('izmir')) {
      return const LatLng(38.4237, 27.1428);
    }
    if (n == 'istanbul' || n.contains('istanbul')) {
      return const LatLng(41.0082, 28.9784);
    }
    if (n == 'ankara' || n.contains('ankara')) {
      return const LatLng(39.9334, 32.8597);
    }
    return null;
  }

  List<String> _queryVariants(String query) {
    final q = query.trim();
    final out = <String>{q};
    final lower = q.toLowerCase();
    if (lower.contains('mahallesi')) {
      out.add(q.replaceAll(RegExp(r'(?i)mahallesi'), 'Mah.'));
      out.add(q.replaceAll(RegExp(r'(?i)mahallesi'), '').trim());
    }
    if (lower.contains(' mah.')) {
      out.add(q.replaceAll(RegExp(r'(?i)\smah\.'), ' Mahallesi'));
      out.add(q.replaceAll(RegExp(r'(?i)\smah\.'), '').trim());
    }
    return out.where((e) => e.isNotEmpty).toList();
  }

  Future<LatLng?> _fromNominatim(String query) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
            '?format=jsonv2'
            '&limit=1'
            '&countrycodes=tr'
            '&q=${Uri.encodeQueryComponent(query)}',
      );
      final res = await http.get(
        uri,
        headers: const {
          'User-Agent': 'SafeHerApp/1.0',
          'Accept': 'application/json',
        },
      );
      if (res.statusCode != 200) return null;
      final arr = jsonDecode(res.body) as List<dynamic>;
      if (arr.isEmpty) return null;
      final first = arr.first as Map<String, dynamic>;
      final lat = double.tryParse((first['lat'] ?? '').toString());
      final lon = double.tryParse((first['lon'] ?? '').toString());
      if (lat == null || lon == null) return null;
      return LatLng(lat, lon);
    } catch (_) {
      return null;
    }
  }

  String _normalizeTurkish(String input) {
    return input
        .replaceAll('ç', 'c')
        .replaceAll('Ç', 'C')
        .replaceAll('ğ', 'g')
        .replaceAll('Ğ', 'G')
        .replaceAll('ı', 'i')
        .replaceAll('İ', 'I')
        .replaceAll('ö', 'o')
        .replaceAll('Ö', 'O')
        .replaceAll('ş', 's')
        .replaceAll('Ş', 'S')
        .replaceAll('ü', 'u')
        .replaceAll('Ü', 'U');
  }
}

