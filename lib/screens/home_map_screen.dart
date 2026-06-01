import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/pins_repository.dart';
import '../l10n/app_strings.dart';
import '../models/map_pin_visibility.dart';
import '../models/safety_pin.dart';
import '../services/geocoding_service.dart';
import '../services/local_notify_service.dart';
import '../theme/app_theme.dart';
import '../utils/route_corridor.dart';

class HomeMapScreen extends StatefulWidget {
  const HomeMapScreen({
    super.key,
    required this.mapPinIntentListenable,
  });

  /// Profil kartlarından gelen “haritada şu pinleri göster” isteği.
  final ValueListenable<MapPinFilterIntent?> mapPinIntentListenable;

  @override
  State<HomeMapScreen> createState() => _HomeMapScreenState();
}

class _HomeMapScreenState extends State<HomeMapScreen> {
  final PinsRepository _pinsRepository = PinsRepository();
  final GeocodingService _geocodingService = GeocodingService();

  static const _safeTags = <String>[
    'Aydınlık',
    'Kalabalık',
    'Kamera var',
    'Polis noktası var',
    'Merkezi konum',
  ];

  static const _dangerTags = <String>[
    'Tenha',
    'Sokak lambası yok',
    'Tedirgin edici insanlar',
    'Kamera yok',
    'Issız',
  ];

  /// Overpass sık 406/timeout verir; User-Agent + yedek sunucular gerekli.
  static const _overpassInterpreterUrls = <String>[
    'https://overpass-api.de/api/interpreter',
    'https://lz4.overpass-api.de/api/interpreter',
    'https://z.overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
  ];

  static const _overpassUserAgent =
      'SafeHer/1.0.3 (https://safeherapp.com; support@safeherapp.com)';

  static const Duration _overpassHttpTimeout = Duration(seconds: 45);

  static final Map<String, String> _overpassHeaders = {
    'User-Agent': _overpassUserAgent,
    'Accept': 'application/json',
    'Content-Type': 'application/x-www-form-urlencoded',
  };

  Future<http.Response?> _postOverpass(String query) async {
    for (final url in _overpassInterpreterUrls) {
      try {
        final res = await http
            .post(
              Uri.parse(url),
              headers: _overpassHeaders,
              body: {'data': query},
            )
            .timeout(_overpassHttpTimeout);
        if (res.statusCode == 200 &&
            !res.body.contains('<html') &&
            !res.body.contains('<!DOCTYPE')) {
          return res;
        }
      } catch (_) {}
    }
    return null;
  }

  List<_BusStop> _parseOverpassElements(String body) {
    try {
      final map = jsonDecode(body) as Map<String, dynamic>;
      final elements = (map['elements'] as List<dynamic>? ?? const []);
      return elements
          .map((e) {
            final m = e as Map<String, dynamic>;
            final tags = (m['tags'] as Map<String, dynamic>? ?? const {});
            final center = m['center'] as Map<String, dynamic>?;
            return _BusStop(
              lat: ((m['lat'] as num?)?.toDouble() ??
                  (center?['lat'] as num?)?.toDouble() ??
                  0),
              lng: ((m['lon'] as num?)?.toDouble() ??
                  (center?['lon'] as num?)?.toDouble() ??
                  0),
              name: (tags['name'] as String?) ?? '',
            );
          })
          .where((e) => e.lat != 0 && e.lng != 0)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _routeDestinationController =
      TextEditingController();
  GoogleMapController? _mapController;
  LatLng? _pendingCameraTarget;
  LatLng? _mapContextTarget;
  bool _myLocationEnabled = false;
  final List<SafetyPin> _offlinePins = [];
  int _offlineId = 0;
  static const _ownPinIdsPrefsKey = 'own_location_pin_ids';
  Set<String> _ownPinIds = {};
  DateTime? _lastPinCreatedAt;
  Set<Marker> _busStopMarkers = <Marker>{};
  Set<Marker> _healthMarkers = <Marker>{};
  Set<Polyline> _routePolylines = {};
  static const double _routeCorridorMeters = 220;

  MapPinVisibilityFilter _pinVisibilityFilter = MapPinVisibilityFilter.all;
  late final VoidCallback _mapPinIntentListener = _onMapPinIntentFromProfile;

  bool _pinMatchesVisibility(SafetyPin pin) {
    switch (_pinVisibilityFilter) {
      case MapPinVisibilityFilter.all:
        return true;
      case MapPinVisibilityFilter.safeOnly:
        return pin.isSafe;
      case MapPinVisibilityFilter.unsafeOnly:
        return !pin.isSafe;
    }
  }
  bool _isFindingBusStops = false;
  bool _isFindingHospitals = false;
  bool _isFindingPharmacies = false;
  bool _didAutoCenterOnLaunch = false;
  static const double _streetFocusZoom = 17;

  @override
  void initState() {
    super.initState();
    widget.mapPinIntentListenable.addListener(_mapPinIntentListener);
    _loadOwnPinIds();
    _initUserLocation();
  }

  Future<void> _loadOwnPinIds() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_ownPinIdsPrefsKey) ?? [];
    if (!mounted) return;
    setState(() => _ownPinIds = stored.toSet());
  }

  Future<void> _rememberOwnPinId(String pinId) async {
    if (pinId.isEmpty) return;
    _ownPinIds.add(pinId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_ownPinIdsPrefsKey, _ownPinIds.toList());
  }

  Future<void> _forgetOwnPinId(String pinId) async {
    _ownPinIds.remove(pinId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_ownPinIdsPrefsKey, _ownPinIds.toList());
  }

  bool _canDeletePin(SafetyPin pin, String? uid) {
    if (_isOfflinePin(pin)) return true;
    if (uid == null) return false;
    if (pin.ownerUid == uid) return true;
    return _ownPinIds.contains(pin.id);
  }

  void _onMapPinIntentFromProfile() {
    final intent = widget.mapPinIntentListenable.value;
    if (intent == null) return;
    if (!mounted) return;
    setState(() => _pinVisibilityFilter = intent.filter);
    Future.microtask(() async {
      if (!mounted) return;
      await _fitCameraForPinVisibility();
    });
  }

  @override
  void dispose() {
    widget.mapPinIntentListenable.removeListener(_mapPinIntentListener);
    _searchController.dispose();
    _routeDestinationController.dispose();
    super.dispose();
  }

  Future<void> _initUserLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (!mounted) return;

      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        setState(() => _myLocationEnabled = true);
        // Prefer last known location for fast first paint, then fallback to live fix.
        Position? pos = await Geolocator.getLastKnownPosition();
        pos ??= await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        ).timeout(const Duration(seconds: 12));

        final target = LatLng(pos.latitude, pos.longitude);
        _mapContextTarget = target;
        if (_mapController == null) {
          _pendingCameraTarget = target;
        } else {
          await _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(target, _streetFocusZoom),
          );
        }
      }
    } catch (_) {
      // Location is optional for MVP; ignore failures.
    }
  }

  Future<void> _tryAutoCenterAfterMapReady() async {
    if (_didAutoCenterOnLaunch) return;
    _didAutoCenterOnLaunch = true;

    try {
      final pos = await _tryGetCurrentPosition();
      if (pos == null) return;
      final target = LatLng(pos.latitude, pos.longitude);
      _mapContextTarget = target;
      if (_mapController != null) {
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(target, _streetFocusZoom),
        );
      } else {
        _pendingCameraTarget = target;
      }
    } catch (_) {
      // Ignore silently; user can still search or use map manually.
    }
  }

  Set<Marker> _markersFromPins(List<SafetyPin> pins) {
    final combined = [...pins, ..._offlinePins];
    final visible = combined.where(_pinMatchesVisibility);
    final pinMarkers = visible
        .map((pin) => Marker(
              markerId: MarkerId(pin.id),
              position: LatLng(pin.lat, pin.lng),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                pin.isSafe ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
              ),
              consumeTapEvents: true,
              onTap: () => _showPinDetails(pin),
            ))
        .toSet();
    return {...pinMarkers, ..._busStopMarkers, ..._healthMarkers};
  }

  Future<void> _fitCameraForPinVisibility() async {
    if (!mounted || _mapController == null) return;
    try {
      final pins = await _pinsRepository.watchPins().first;
      final filtered =
          [...pins, ..._offlinePins].where(_pinMatchesVisibility).toList();
      if (filtered.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.t('mapFilterEmpty'))),
          );
        }
        return;
      }
      var minLat = filtered.first.lat;
      var maxLat = filtered.first.lat;
      var minLng = filtered.first.lng;
      var maxLng = filtered.first.lng;
      for (final p in filtered.skip(1)) {
        minLat = math.min(minLat, p.lat);
        maxLat = math.max(maxLat, p.lat);
        minLng = math.min(minLng, p.lng);
        maxLng = math.max(maxLng, p.lng);
      }
      const pad = 0.035;
      if (!mounted || _mapController == null) return;
      try {
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(
            LatLngBounds(
              southwest: LatLng(minLat - pad, minLng - pad),
              northeast: LatLng(maxLat + pad, maxLng + pad),
            ),
            80,
          ),
        );
      } catch (_) {
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2),
            14,
          ),
        );
      }
    } catch (_) {}
  }

  bool _isOfflinePin(SafetyPin pin) => pin.id.startsWith('local_');

  String _getScoreText(int likes, int dislikes) {
    final score = likes - dislikes;
    if (score <= 0) return 'Zayıf';
    if (score < 5) return 'Orta';
    return 'İyi';
  }

  Future<void> _onSearchSubmitted(String value) async {
    final query = value.trim();
    if (query.isEmpty) return;

    try {
      final target = await _geocodeWithFallback(query);
      if (target == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Adres bulunamadı.')),
        );
        return;
      }
      _mapContextTarget = target;
      if (_mapController == null) {
        _pendingCameraTarget = target;
        return;
      }

      await _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(target, 14),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Arama hatası: $e')),
      );
    }
  }

  Future<LatLng?> _geocodeWithFallback(String query) async {
    String? localityHint;
    String? adminHint;
    if (_mapContextTarget != null) {
      try {
        final places = await placemarkFromCoordinates(
          _mapContextTarget!.latitude,
          _mapContextTarget!.longitude,
        );
        if (places.isNotEmpty) {
          final p = places.first;
          localityHint = p.subAdministrativeArea ?? p.locality;
          adminHint = p.administrativeArea;
        }
      } catch (_) {
        // Hint is optional.
      }
    }

    try {
      return await _geocodingService.geocodeAddress(
        query,
        localityHint: localityHint,
        adminHint: adminHint,
      );
    } catch (_) {
      final normalized = _normalizeTurkish(query);
      if (normalized == query) return null;
      try {
        return await _geocodingService.geocodeAddress(
          normalized,
          localityHint: localityHint,
          adminHint: adminHint,
        );
      } catch (_) {
        return null;
      }
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

  void _setNearbyLoading({bool? bus, bool? hospitals, bool? pharmacies}) {
    if (!mounted) return;
    setState(() {
      if (bus != null) _isFindingBusStops = bus;
      if (hospitals != null) _isFindingHospitals = hospitals;
      if (pharmacies != null) _isFindingPharmacies = pharmacies;
    });
  }

  void _showNearbySearchSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          duration: const Duration(days: 1),
        ),
      );
  }

  void _hideNearbySearchSnack() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  Widget _nearbyActionIcon(bool loading, IconData icon) {
    if (loading) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.white,
        ),
      );
    }
    return Icon(icon);
  }

  Future<Position?> _tryGetCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return null;
      }

      return Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      ).timeout(const Duration(seconds: 15));
    } catch (_) {
      return null;
    }
  }

  Future<void> _openNearbyBusStops() async {
    if (_isFindingBusStops) return;
    _setNearbyLoading(bus: true);
    _showNearbySearchSnack(context.t('searchingBuses'));
    await Future<void>.delayed(Duration.zero);

    final target = await _resolveTargetForNearby();
    if (!mounted) return;
    if (target == null) {
      _hideNearbySearchSnack();
      _setNearbyLoading(bus: false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Konum alınamadı. Lütfen konum iznini ve GPS’i açın.'),
        ),
      );
      return;
    }

    final lat = target.latitude;
    final lng = target.longitude;
    final result = await _fetchNearbyBusStops(lat, lng);
    if (!mounted) return;

    if (!result.requestOk) {
      _hideNearbySearchSnack();
      _setNearbyLoading(bus: false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Durak verisi alınamadı. İnternet bağlantınızı kontrol edip tekrar deneyin.',
          ),
        ),
      );
      return;
    }

    final nearby = result.items;
    if (nearby.isEmpty) {
      _hideNearbySearchSnack();
      _setNearbyLoading(bus: false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yakında durak bulunamadı.')),
      );
      return;
    }

    setState(() {
      _busStopMarkers = nearby.map((stop) {
        return Marker(
          markerId: MarkerId('bus_${stop.name}_${stop.lat}_${stop.lng}'),
          position: LatLng(stop.lat, stop.lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: InfoWindow(
            title: stop.name.isEmpty ? 'Otobüs Durağı' : stop.name,
            snippet: 'Yakındaki durak',
          ),
        );
      }).toSet();
    });

    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(lat, lng), 15),
    );

    if (!mounted) return;
    _hideNearbySearchSnack();
    _setNearbyLoading(bus: false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${nearby.length} durak haritada gösteriliyor.')),
    );
  }

  Future<({List<_BusStop> items, bool requestOk})> _fetchNearbyBusStops(
    double lat,
    double lng,
  ) async {
    final seen = <String>{};
    final merged = <_BusStop>[];
    var requestOk = false;

    for (final radius in const [1500, 3000, 6000]) {
      final query = '''
[out:json][timeout:35];
(
  node["highway"="bus_stop"](around:$radius,$lat,$lng);
  way["highway"="bus_stop"](around:$radius,$lat,$lng);
  node["public_transport"="platform"]["bus"="yes"](around:$radius,$lat,$lng);
  node["public_transport"="stop_position"](around:$radius,$lat,$lng);
  node["public_transport"="stop_area"](around:$radius,$lat,$lng);
  node["amenity"="bus_station"](around:$radius,$lat,$lng);
  way["amenity"="bus_station"](around:$radius,$lat,$lng);
);
out center 100;
''';
      final res = await _postOverpass(query);
      if (res == null) {
        if (!requestOk) return (items: const <_BusStop>[], requestOk: false);
        break;
      }
      requestOk = true;
      for (final p in _parseOverpassElements(res.body)) {
        final key =
            '${p.lat.toStringAsFixed(5)}_${p.lng.toStringAsFixed(5)}_${p.name}';
        if (seen.add(key)) merged.add(p);
      }
      if (merged.length >= 20) break;
    }

    merged.sort((a, b) {
      final da = _distanceMeters(lat, lng, a.lat, a.lng);
      final db = _distanceMeters(lat, lng, b.lat, b.lng);
      return da.compareTo(db);
    });
    return (items: merged.take(40).toList(), requestOk: requestOk);
  }

  Future<({List<_BusStop> items, bool requestOk})> _fetchNearbyPlaces({
    required double lat,
    required double lng,
    required String overpassFilter,
    required int radius,
    int outLimit = 60,
  }) async {
    final query = '''
[out:json][timeout:35];
(
  node[$overpassFilter](around:$radius,$lat,$lng);
  way[$overpassFilter](around:$radius,$lat,$lng);
  relation[$overpassFilter](around:$radius,$lat,$lng);
);
out center $outLimit;
''';
    final res = await _postOverpass(query);
    if (res == null) return (items: const <_BusStop>[], requestOk: false);
    return (items: _parseOverpassElements(res.body), requestOk: true);
  }

  Future<({List<_BusStop> places, bool requestOk})> _fetchNearestPlacesFast({
    required double lat,
    required double lng,
    required String overpassFilter,
    required int radius,
    required int maxResults,
    int outLimit = 80,
  }) async {
    final fetched = await _fetchNearbyPlaces(
      lat: lat,
      lng: lng,
      overpassFilter: overpassFilter,
      radius: radius,
      outLimit: outLimit,
    );
    if (!fetched.requestOk) {
      return (places: const <_BusStop>[], requestOk: false);
    }
    final results = fetched.items;
    if (results.isEmpty) return (places: const <_BusStop>[], requestOk: true);

    final seen = <String>{};
    final deduped = <_BusStop>[];
    for (final p in results) {
      final key =
          '${p.lat.toStringAsFixed(5)}_${p.lng.toStringAsFixed(5)}_${p.name}';
      if (seen.add(key)) deduped.add(p);
    }

    deduped.sort((a, b) {
      final da = _distanceMeters(lat, lng, a.lat, a.lng);
      final db = _distanceMeters(lat, lng, b.lat, b.lng);
      return da.compareTo(db);
    });
    return (
      places: deduped.take(maxResults).toList(),
      requestOk: true,
    );
  }

  Future<({List<_BusStop> places, bool requestOk})>
      _fetchNearestPlacesWithExpansion({
    required double lat,
    required double lng,
    required String overpassFilter,
    required List<int> radii,
    required int maxResults,
    int outLimit = 100,
  }) async {
    final seen = <String>{};
    final merged = <_BusStop>[];
    var requestOk = false;
    for (final r in radii) {
      final fetched = await _fetchNearbyPlaces(
        lat: lat,
        lng: lng,
        overpassFilter: overpassFilter,
        radius: r,
        outLimit: outLimit,
      );
      if (!fetched.requestOk) continue;
      requestOk = true;
      final batch = fetched.items;
      for (final p in batch) {
        final key =
            '${p.lat.toStringAsFixed(5)}_${p.lng.toStringAsFixed(5)}_${p.name}';
        if (seen.add(key)) merged.add(p);
      }
    }
    if (!requestOk) return (places: const <_BusStop>[], requestOk: false);
    if (merged.isEmpty) return (places: const <_BusStop>[], requestOk: true);
    merged.sort((a, b) {
      final da = _distanceMeters(lat, lng, a.lat, a.lng);
      final db = _distanceMeters(lat, lng, b.lat, b.lng);
      return da.compareTo(db);
    });
    return (places: merged.take(maxResults).toList(), requestOk: true);
  }

  double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const earth = 6371000.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earth * c;
  }

  double _degToRad(double d) => d * 0.017453292519943295;

  List<_BusStop> _mergeByDistance(
    double lat,
    double lng,
    List<List<_BusStop>> groups,
    int maxResults,
  ) {
    final seen = <String>{};
    final merged = <_BusStop>[];
    for (final g in groups) {
      for (final p in g) {
        final key =
            '${p.lat.toStringAsFixed(5)}_${p.lng.toStringAsFixed(5)}_${p.name}';
        if (seen.add(key)) merged.add(p);
      }
    }
    merged.sort((a, b) {
      final da = _distanceMeters(lat, lng, a.lat, a.lng);
      final db = _distanceMeters(lat, lng, b.lat, b.lng);
      return da.compareTo(db);
    });
    return merged.take(maxResults).toList();
  }

  Future<void> _showNearbyHospitals() async {
    if (_isFindingHospitals) return;
    _setNearbyLoading(hospitals: true);
    _showNearbySearchSnack(context.t('searchingHospitals'));
    await Future<void>.delayed(Duration.zero);

    final target = await _resolveHealthSearchOrigin();
    if (!mounted) return;
    if (target == null) {
      _hideNearbySearchSnack();
      _setNearbyLoading(hospitals: false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Konum alınamadı. Lütfen konum iznini ve GPS’i açın.'),
        ),
      );
      return;
    }

    final lat = target.latitude;
    final lng = target.longitude;

    final hospitalBatches = await Future.wait([
      _fetchNearestPlacesFast(
        lat: lat,
        lng: lng,
        overpassFilter: '"amenity"="hospital"',
        radius: 10000,
        maxResults: 10,
        outLimit: 100,
      ),
      _fetchNearestPlacesFast(
        lat: lat,
        lng: lng,
        overpassFilter: '"amenity"="clinic"',
        radius: 10000,
        maxResults: 10,
        outLimit: 80,
      ),
      _fetchNearestPlacesFast(
        lat: lat,
        lng: lng,
        overpassFilter: '"healthcare"="hospital"',
        radius: 10000,
        maxResults: 10,
        outLimit: 80,
      ),
      _fetchNearestPlacesFast(
        lat: lat,
        lng: lng,
        overpassFilter: '"healthcare"="clinic"',
        radius: 10000,
        maxResults: 10,
        outLimit: 80,
      ),
    ]);

    var anyRequestOk = hospitalBatches.any((b) => b.requestOk);
    var combined = _mergeByDistance(
      lat,
      lng,
      hospitalBatches.map((b) => b.places).toList(),
      10,
    );

    if (combined.isEmpty) {
      final expanded = await Future.wait([
        _fetchNearestPlacesWithExpansion(
          lat: lat,
          lng: lng,
          overpassFilter: '"amenity"="hospital"',
          radii: const [4000, 8000, 15000, 30000, 50000],
          maxResults: 20,
          outLimit: 120,
        ),
        _fetchNearestPlacesWithExpansion(
          lat: lat,
          lng: lng,
          overpassFilter: '"amenity"="clinic"',
          radii: const [4000, 8000, 15000, 30000, 50000],
          maxResults: 20,
          outLimit: 120,
        ),
        _fetchNearestPlacesWithExpansion(
          lat: lat,
          lng: lng,
          overpassFilter: '"healthcare"="hospital"',
          radii: const [4000, 8000, 15000, 30000, 50000],
          maxResults: 20,
          outLimit: 120,
        ),
        _fetchNearestPlacesWithExpansion(
          lat: lat,
          lng: lng,
          overpassFilter: '"healthcare"="clinic"',
          radii: const [4000, 8000, 15000, 30000, 50000],
          maxResults: 20,
          outLimit: 120,
        ),
      ]);
      anyRequestOk = anyRequestOk || expanded.any((b) => b.requestOk);
      combined = _mergeByDistance(
        lat,
        lng,
        expanded.map((b) => b.places).toList(),
        10,
      );
    }

    if (!mounted) return;
    if (combined.isEmpty) {
      _hideNearbySearchSnack();
      _setNearbyLoading(hospitals: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            anyRequestOk
                ? 'Yakında hastane bulunamadı.'
                : 'Hastane verisi alınamadı. İnternet bağlantınızı kontrol edip tekrar deneyin.',
          ),
        ),
      );
      return;
    }

    _hideNearbySearchSnack();
    setState(() {
      _healthMarkers = {
        ..._healthMarkers.where(
          (m) => !m.markerId.value.startsWith('hospital_'),
        ),
        ...combined.map(
          (p) => Marker(
                markerId: MarkerId('hospital_${p.name}_${p.lat}_${p.lng}'),
                position: LatLng(p.lat, p.lng),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
                infoWindow: InfoWindow(
                  title: p.name.isEmpty ? 'Hastane' : p.name,
                  snippet: 'Yakındaki hastane',
                ),
              ),
        ),
      };
    });
    final first = combined.first;
    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(first.lat, first.lng), 14),
    );
    _setNearbyLoading(hospitals: false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${combined.length} sağlık noktası haritada (en yakına göre) gösteriliyor.',
        ),
      ),
    );
  }

  Future<void> _showNearbyPharmacies() async {
    if (_isFindingPharmacies) return;
    _setNearbyLoading(pharmacies: true);
    _showNearbySearchSnack(context.t('searchingPharmacies'));
    await Future<void>.delayed(Duration.zero);

    final target = await _resolveHealthSearchOrigin();
    if (!mounted) return;
    if (target == null) {
      _hideNearbySearchSnack();
      _setNearbyLoading(pharmacies: false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Konum alınamadı. Lütfen konum iznini ve GPS’i açın.'),
        ),
      );
      return;
    }

    final lat = target.latitude;
    final lng = target.longitude;

    var batch = await _fetchNearestPlacesFast(
      lat: lat,
      lng: lng,
      overpassFilter: '"amenity"="pharmacy"',
      radius: 8000,
      maxResults: 12,
      outLimit: 100,
    );
    var anyRequestOk = batch.requestOk;
    if (batch.places.isEmpty) {
      batch = await _fetchNearestPlacesWithExpansion(
        lat: lat,
        lng: lng,
        overpassFilter: '"amenity"="pharmacy"',
        radii: const [2500, 5000, 10000, 20000, 40000],
        maxResults: 20,
        outLimit: 120,
      );
      anyRequestOk = anyRequestOk || batch.requestOk;
    }
    final pharmacies = _mergeByDistance(lat, lng, [batch.places], 12);
    if (!mounted) return;
    if (pharmacies.isEmpty) {
      _hideNearbySearchSnack();
      _setNearbyLoading(pharmacies: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            anyRequestOk
                ? 'Yakında eczane bulunamadı.'
                : 'Eczane verisi alınamadı. İnternet bağlantınızı kontrol edip tekrar deneyin.',
          ),
        ),
      );
      return;
    }

    _hideNearbySearchSnack();
    setState(() {
      _healthMarkers = {
        ..._healthMarkers.where(
          (m) => !m.markerId.value.startsWith('pharmacy_'),
        ),
        ...pharmacies.map(
          (p) => Marker(
                markerId: MarkerId('pharmacy_${p.name}_${p.lat}_${p.lng}'),
                position: LatLng(p.lat, p.lng),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
                infoWindow: InfoWindow(
                  title: p.name.isEmpty ? 'Eczane' : p.name,
                  snippet: 'Yakındaki eczane',
                ),
              ),
        ),
      };
    });
    final first = pharmacies.first;
    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(first.lat, first.lng), 14),
    );
    _setNearbyLoading(pharmacies: false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${pharmacies.length} eczane haritada (en yakınlar) gösteriliyor.',
        ),
      ),
    );
  }

  Future<void> _openTaxiAction() async {
    final target = await _resolveTargetForNearby();
    if (!mounted) return;

    if (target == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Konum alınamadı. Lütfen konum iznini ve GPS’i açın.'),
        ),
      );
      return;
    }

    final lat = target.latitude;
    final lng = target.longitude;
    await _showTaxiPicker(lat, lng);
  }

  Future<LatLng?> _resolveTargetForNearby() async {
    final pos = await _tryGetCurrentPosition();
    if (pos != null) return LatLng(pos.latitude, pos.longitude);
    if (_mapContextTarget != null) return _mapContextTarget;
    return null;
  }

  /// Hastane / eczane için önce **GPS**; yoksa harita merkezi (arama sonrası yanlış “yakın” olmasın).
  Future<LatLng?> _resolveHealthSearchOrigin() async {
    final pos = await _tryGetCurrentPosition();
    if (pos != null) return LatLng(pos.latitude, pos.longitude);
    if (_mapContextTarget != null) return _mapContextTarget;
    return null;
  }

  Future<void> _showTaxiPicker(double lat, double lng) async {
    final options = <_TaxiOption>[
      _TaxiOption(
        name: 'BiTaksi',
        short: 'B',
        color: const Color(0xFF2DB7FF),
        appUri: Uri.parse('bitaksi://'),
        webUri: Uri.parse('https://www.bitaksi.com/'),
      ),
      _TaxiOption(
        name: 'iTaksi',
        short: 'i',
        color: const Color(0xFF7B4DFF),
        appUri: Uri.parse('itaksi://'),
        webUri: Uri.parse('https://itaksi.com/'),
      ),
      _TaxiOption(
        name: 'Uber',
        short: 'U',
        color: const Color(0xFF111827),
        appUri: Uri.parse('uber://'),
        webUri: Uri.parse('https://m.uber.com/'),
      ),
      _TaxiOption(
        name: 'Yandex Go',
        short: 'Y',
        color: const Color(0xFFFFCC00),
        appUri: Uri.parse('yandextaxi://'),
        webUri: Uri.parse('https://taxi.yandex.com/'),
      ),
      _TaxiOption(
        name: 'Getir',
        short: 'G',
        color: const Color(0xFF5D3EBC),
        appUri: Uri.parse('getir://'),
        webUri: Uri.parse('https://getir.com/'),
      ),
    ];

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1F1840),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Taksi Uygulaması Seç',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                ...options.map((o) {
                  return ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    tileColor: Colors.white.withValues(alpha: 0.08),
                    leading: CircleAvatar(
                      backgroundColor: o.color,
                      child: Text(
                        o.short,
                        style: TextStyle(
                          color: o.short == 'Y' ? Colors.black : Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    title: Text(
                      o.name,
                      style: const TextStyle(color: Colors.white),
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      await _openTaxiOption(o);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openTaxiOption(_TaxiOption option) async {
    if (await canLaunchUrl(option.appUri)) {
      final ok = await launchUrl(
        option.appUri,
        mode: LaunchMode.externalApplication,
      );
      if (ok) return;
    }

    if (!mounted) return;
    if (option.webUri != null) {
      final ok = await launchUrl(
        option.webUri!,
        mode: LaunchMode.externalApplication,
      );
      if (ok) return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('${option.name} açılamadı.')));
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_pendingCameraTarget != null) {
      final target = _pendingCameraTarget!;
      _pendingCameraTarget = null;
      _mapContextTarget = target;
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(target, _streetFocusZoom),
      );
    }
    _tryAutoCenterAfterMapReady();
  }

  Future<void> _addPinAt(LatLng position) async {
    final now = DateTime.now();
    if (_lastPinCreatedAt != null &&
        now.difference(_lastPinCreatedAt!).inSeconds < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Çok hızlı işaretleme yaptınız. Lütfen 10 sn bekleyin.'),
        ),
      );
      return;
    }

    bool? isSafe;
    final selectedTags = <String>[];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final currentTags =
                isSafe == null ? const <String>[] : (isSafe! ? _safeTags : _dangerTags);

            return AnimatedPadding(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F1FF),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                ),
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  16 + MediaQuery.of(context).viewPadding.bottom + 12,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                  const Text(
                    'Burası güvenli mi?',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF32204F),
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => setState(() {
                            isSafe = true;
                            selectedTags.clear();
                          }),
                          icon: const Icon(Icons.check_circle, color: Colors.green),
                          label: const Text(
                            'Güvenli',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.green,
                            textStyle: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => setState(() {
                            isSafe = false;
                            selectedTags.clear();
                          }),
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          label: const Text(
                            'Güvensiz',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            textStyle: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (isSafe != null) ...[
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Etiket Seç',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.15,
                          color: isSafe!
                              ? const Color(0xFF239457)
                              : const Color(0xFFCB3A4F),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: currentTags.map((tag) {
                        final safeNow = isSafe ?? true;
                        final selected = selectedTags.contains(tag);
                        return ChoiceChip(
                          label: Text(tag),
                          labelStyle: TextStyle(
                            color: selected
                                ? (safeNow ? Colors.green.shade900 : Colors.red.shade900)
                                : Colors.black87,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          backgroundColor: Colors.white,
                          selectedColor: (safeNow ? Colors.green : Colors.red)
                              .withValues(alpha: 0.22),
                          side: BorderSide(
                            color: selected
                                ? (safeNow ? Colors.green.shade300 : Colors.red.shade300)
                                : Colors.black12,
                          ),
                          checkmarkColor:
                              safeNow ? Colors.green.shade700 : Colors.red.shade700,
                          selected: selected,
                          onSelected: (_) {
                            setState(() {
                              selected
                                  ? selectedTags.remove(tag)
                                  : selectedTags.add(tag);
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                  ],
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                        onPressed: isSafe == null
                            ? null
                            : () async {
                            final safe = isSafe!;
                            try {
                              final newId = await _pinsRepository.addPin(
                                lat: position.latitude,
                                lng: position.longitude,
                                isSafe: safe,
                                tags: selectedTags.toList(),
                              );
                              await _rememberOwnPinId(newId);
                            } catch (e) {
                              // Fallback: if Firestore write fails, keep pin locally
                              // so user can still continue using the map.
                              final localPin = SafetyPin(
                                id: 'local_${_offlineId++}',
                                lat: position.latitude,
                                lng: position.longitude,
                                isSafe: safe,
                                tags: selectedTags.toList(),
                                likes: 0,
                                dislikes: 0,
                                ownerUid: FirebaseAuth.instance.currentUser?.uid,
                              );
                              if (mounted) {
                                setState(() => _offlinePins.add(localPin));
                              }
                              if (!context.mounted) return;
                              final err = e.toString();
                              final permissionIssue =
                                  err.contains('PERMISSION_DENIED') ||
                                  err.contains('Missing or insufficient permissions');
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    permissionIssue
                                        ? 'Bulut yazma izni yok. Marker yerelde kaydedildi.'
                                        : 'Buluta kaydedilemedi, yerelde kaydedildi: $e',
                                  ),
                                ),
                              );
                              Navigator.pop(context);
                              return;
                            }
                            if (!context.mounted) return;
                            _lastPinCreatedAt = DateTime.now();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('İşaret kaydedildi')),
                            );
                            Navigator.pop(context);
                          },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 12,
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: const Text('Kaydet'),
                      ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showPinDetails(SafetyPin pin) async {
    if (!context.mounted) return;

    int likes = pin.likes;
    int dislikes = pin.dislikes;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final canDelete = _canDeletePin(pin, uid);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      builder: (sheetContext) {
        const kInk = Color(0xFF12082A);
        const kChipFill = Color(0xFFE4D8FF);
        const kChipBorder = Color(0xFF5C2FA8);

        final sheetTheme = ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF5C2FA8),
            brightness: Brightness.light,
          ),
          textTheme: ThemeData.light().textTheme.apply(
            bodyColor: kInk,
            displayColor: kInk,
          ),
          chipTheme: ChipThemeData(
            backgroundColor: kChipFill,
            disabledColor: Colors.grey.shade300,
            selectedColor: const Color(0xFFD4C4FF),
            deleteIconColor: kChipBorder,
            labelStyle: const TextStyle(
              color: kInk,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              height: 1.25,
            ),
            secondaryLabelStyle: const TextStyle(
              color: kInk,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            side: const BorderSide(color: kChipBorder, width: 1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          ),
        );

        Widget tagChip(String text) {
          return Chip(
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            backgroundColor: kChipFill,
            side: const BorderSide(color: kChipBorder, width: 1),
            label: Text(
              text,
              style: const TextStyle(
                color: kInk,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                height: 1.25,
              ),
            ),
          );
        }

        return Theme(
          data: sheetTheme,
          child: StatefulBuilder(
            builder: (context, setModalState) {
              final isSafe = pin.isSafe;
              const kBody = Color(0xFF1A0F3D);
              final zoneColor =
                  isSafe ? const Color(0xFF1B5E20) : const Color(0xFFB71C1C);

              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Kullanıcı Rozeti',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: kBody,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.person, color: Colors.grey.shade800),
                        const SizedBox(width: 6),
                        Text(
                          'Yeni Üye',
                          style: TextStyle(
                            color: Colors.grey.shade900,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    Row(
                      children: [
                        Icon(
                          Icons.circle,
                          color: isSafe ? Colors.green.shade700 : Colors.red.shade700,
                          size: 12,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isSafe ? 'Güvenli Bölge' : 'Güvensiz Bölge',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: zoneColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: pin.tags.isEmpty
                          ? [tagChip(sheetContext.t('mapPinTagsEmpty'))]
                          : pin.tags.map(tagChip).toList(),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.thumb_up, color: Colors.green),
                          onPressed: () async {
                            if (_isOfflinePin(pin)) {
                              setModalState(() => likes += 1);
                              return;
                            }
                            await _pinsRepository.likePin(pin.id);
                            setModalState(() => likes += 1);
                          },
                        ),
                        Text(
                          '$likes',
                          style: const TextStyle(
                            color: kBody,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 20),
                        IconButton(
                          icon: const Icon(Icons.thumb_down, color: Colors.red),
                          onPressed: () async {
                            if (_isOfflinePin(pin)) {
                              setModalState(() => dislikes += 1);
                              return;
                            }
                            await _pinsRepository.dislikePin(pin.id);
                            setModalState(() => dislikes += 1);
                          },
                        ),
                        Text(
                          '$dislikes',
                          style: const TextStyle(
                            color: kBody,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Güven Skoru: ${likes - dislikes}',
                      style: TextStyle(
                        color: Colors.red.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Topluluk Değerlendirmesi: ${_getScoreText(likes, dislikes)}',
                      style: TextStyle(
                        color: Colors.red.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (canDelete) ...[
                      const SizedBox(height: 4),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade800,
                            side: BorderSide(color: Colors.red.shade400, width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.delete_outline),
                          label: Text(sheetContext.t('deletePinButton')),
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: sheetContext,
                              builder: (dCtx) => AlertDialog(
                                title: Text(sheetContext.t('deletePinConfirmTitle')),
                                content: Text(sheetContext.t('deletePinConfirmBody')),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(dCtx, false),
                                    child: Text(sheetContext.t('deletePinCancel')),
                                  ),
                                  FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.red.shade700,
                                    ),
                                    onPressed: () => Navigator.pop(dCtx, true),
                                    child: Text(sheetContext.t('deletePinConfirm')),
                                  ),
                                ],
                              ),
                            );
                            if (ok != true) return;

                            if (_isOfflinePin(pin)) {
                              await _forgetOwnPinId(pin.id);
                              if (!sheetContext.mounted) return;
                              Navigator.pop(sheetContext);
                              if (mounted) {
                                setState(() {
                                  _offlinePins.removeWhere((p) => p.id == pin.id);
                                });
                              }
                              if (mounted) {
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  SnackBar(
                                    content: Text(sheetContext.t('deletePinSuccess')),
                                  ),
                                );
                              }
                              return;
                            }
                            try {
                              await _pinsRepository.deletePin(pin.id);
                              await _forgetOwnPinId(pin.id);
                              if (!sheetContext.mounted) return;
                              Navigator.pop(sheetContext);
                              if (mounted) {
                                setState(() {});
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  SnackBar(
                                    content: Text(sheetContext.t('deletePinSuccess')),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (!sheetContext.mounted) return;
                              final msg = e.toString().contains('PERMISSION_DENIED') ||
                                      e.toString().contains('insufficient permissions')
                                  ? sheetContext.t('deletePinOnlyOwner')
                                  : sheetContext.tReplace('deletePinFailed', {
                                      'error': e.toString(),
                                    });
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                SnackBar(content: Text(msg)),
                              );
                            }
                          },
                        ),
                      ),
                    ] else
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          sheetContext.t('deletePinOnlyOwner'),
                          style: TextStyle(
                            color: Colors.grey.shade900,
                            fontSize: 13,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                ],
              ),
            );
          },
        ),
        );
      },
    );
  }

  void _clearPlannedRoute() {
    setState(() => _routePolylines = {});
  }

  void _openRouteSafetyPlanner(List<SafetyPin> pins) {
    _routeDestinationController.clear();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      useSafeArea: true,
      builder: (ctx) => _RoutePlannerSheet(
        controller: _routeDestinationController,
        geocodingService: _geocodingService,
        mapContextTarget: _mapContextTarget,
        pins: pins,
        onAnalyze: (query, picked) {
          Navigator.of(ctx).pop();
          _runRouteSafetyAnalysis(
            pins,
            query,
            destinationLatLng: picked,
          );
        },
      ),
    );
  }

  Future<void> _fitRouteBounds(LatLng a, LatLng b) async {
    if (_mapController == null) return;
    final south = math.min(a.latitude, b.latitude);
    final north = math.max(a.latitude, b.latitude);
    final west = math.min(a.longitude, b.longitude);
    final east = math.max(a.longitude, b.longitude);
    const pad = 0.035;
    try {
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(south - pad, west - pad),
            northeast: LatLng(north + pad, east + pad),
          ),
          72,
        ),
      );
    } catch (_) {
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng((a.latitude + b.latitude) / 2, (a.longitude + b.longitude) / 2),
          14,
        ),
      );
    }
  }

  Future<void> _runRouteSafetyAnalysis(
    List<SafetyPin> pins,
    String destinationQuery, {
    LatLng? destinationLatLng,
  }) async {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    void closeLoader() {
      if (!mounted) return;
      final nav = Navigator.of(context);
      if (nav.canPop()) nav.pop();
    }

    try {
      LatLng? origin;
      final pos = await _tryGetCurrentPosition();
      if (pos != null) origin = LatLng(pos.latitude, pos.longitude);
      origin ??= _mapContextTarget;

      if (origin == null) {
        closeLoader();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('routePlanOriginMissing'))),
        );
        return;
      }

      final dest =
          destinationLatLng ?? await _geocodeWithFallback(destinationQuery);
      if (dest == null) {
        closeLoader();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('routePlanGeocodeFail'))),
        );
        return;
      }

      final hits = <({SafetyPin pin, double meters})>[];
      for (final p in pins) {
        if (p.isSafe) continue;
        final d = minDistanceMetersToSegment(
          LatLng(p.lat, p.lng),
          origin,
          dest,
        );
        if (d <= _routeCorridorMeters) {
          hits.add((pin: p, meters: d));
        }
      }
      hits.sort((a, b) => a.meters.compareTo(b.meters));
      final count = hits.length;

      if (!mounted) return;
      closeLoader();

      final o = origin;
      setState(() {
        _routePolylines = {
          Polyline(
            polylineId: const PolylineId('route_plan'),
            color: const Color(0xFF7B4DFF),
            width: 5,
            geodesic: true,
            points: <LatLng>[o, dest],
          ),
        };
      });

      await _fitRouteBounds(o, dest);

      if (!mounted) return;
      final title = context.t('routeNotifyTitle');
      final body = count > 0
          ? context.tReplace('routeNotifyBodyMany', {'count': '$count'})
          : context.t('routeNotifyBodyZero');
      await LocalNotifyService.instance.showImmediate(title: title, body: body);

      if (!mounted) return;
      _showRouteHitsSheet(hits);
    } catch (e) {
      closeLoader();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  void _showRouteHitsSheet(List<({SafetyPin pin, double meters})> hits) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.45,
          minChildSize: 0.28,
          maxChildSize: 0.9,
          builder: (_, scroll) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: ListView(
                controller: scroll,
                children: [
                  Text(
                    ctx.t('routePlanUnsafeTitle'),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (hits.isEmpty)
                    Text(
                      ctx.t('routePlanUnsafeNone'),
                      style: TextStyle(
                        color: Colors.grey.shade800,
                        height: 1.35,
                      ),
                    )
                  else
                    ...hits.map(
                      (h) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          tileColor: const Color(0xFFFFF3F5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.red.shade200),
                          ),
                          title: Text(
                            ctx.tReplace(
                              'routePlanUnsafeLine',
                              {
                                'meters': '${h.meters.round()}',
                                'tags': h.pin.tags.isEmpty
                                    ? '—'
                                    : h.pin.tags.join(', '),
                              },
                            ),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _clearPlannedRoute();
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: Text(ctx.t('routePlanClearRoute')),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(ctx.t('routePlanClose')),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.pageGradient),
      child: StreamBuilder<List<SafetyPin>>(
        stream: _pinsRepository.watchPins(),
        builder: (context, snapshot) {
          final pins = snapshot.data ?? const <SafetyPin>[];
          return Column(
            children: [
              Material(
            elevation: 0,
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.white.withValues(alpha: 0.18),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onSubmitted: _onSearchSubmitted,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Adres ara (örn. İzmir)',
                        hintStyle:
                            TextStyle(color: Colors.white.withValues(alpha: 0.85)),
                        prefixIcon: const Icon(Icons.search, color: Colors.white),
                        filled: false,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  if (_pinVisibilityFilter != MapPinVisibilityFilter.all) ...[
                    const SizedBox(height: 8),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.amber.withValues(alpha: 0.22),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _pinVisibilityFilter ==
                                        MapPinVisibilityFilter.safeOnly
                                    ? context.t('mapFilterActiveSafe')
                                    : context.t('mapFilterActiveUnsafe'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => setState(
                                () => _pinVisibilityFilter =
                                    MapPinVisibilityFilter.all,
                              ),
                              child: Text(
                                context.t('mapFilterClear'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.65),
                            ),
                            backgroundColor: Colors.white.withValues(alpha: 0.08),
                          ),
                          onPressed:
                              _isFindingBusStops ? null : _openNearbyBusStops,
                          icon: _nearbyActionIcon(
                            _isFindingBusStops,
                            Icons.directions_bus,
                          ),
                          label: Text(
                            _isFindingBusStops
                                ? context.t('searchingBuses')
                                : context.t('nearbyBuses'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.65),
                            ),
                            backgroundColor: Colors.white.withValues(alpha: 0.08),
                          ),
                          onPressed: _openTaxiAction,
                          icon: const Icon(Icons.local_taxi),
                          label: const Text('Taksi Çağır'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.65),
                            ),
                            backgroundColor: Colors.white.withValues(alpha: 0.08),
                          ),
                          onPressed: _isFindingHospitals ? null : _showNearbyHospitals,
                          icon: _nearbyActionIcon(
                            _isFindingHospitals,
                            Icons.local_hospital,
                          ),
                          label: Text(
                            _isFindingHospitals
                                ? context.t('searchingHospitals')
                                : context.t('nearbyHospitals'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.65),
                            ),
                            backgroundColor: Colors.white.withValues(alpha: 0.08),
                          ),
                          onPressed: _isFindingPharmacies ? null : _showNearbyPharmacies,
                          icon: _nearbyActionIcon(
                            _isFindingPharmacies,
                            Icons.local_pharmacy,
                          ),
                          label: Text(
                            _isFindingPharmacies
                                ? context.t('searchingPharmacies')
                                : context.t('nearbyPharmacies'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                      ),
                      onPressed: () => _openRouteSafetyPlanner(pins),
                      icon: const Icon(Icons.alt_route),
                      label: Text(context.t('routePlanButton')),
                    ),
                  ),
                  if (_busStopMarkers.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => setState(() => _busStopMarkers = {}),
                        icon: const Icon(Icons.clear, color: Colors.white),
                        label: const Text(
                          'Durakları Temizle',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                  if (_healthMarkers.isNotEmpty)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => setState(() => _healthMarkers = {}),
                        icon: const Icon(Icons.clear_all, color: Colors.white),
                        label: const Text(
                          'Sağlık İşaretlerini Temizle',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  GoogleMap(
                    initialCameraPosition: const CameraPosition(
                      target: LatLng(41.0082, 28.9784),
                      zoom: 12,
                    ),
                    myLocationEnabled: _myLocationEnabled,
                    markers: _markersFromPins(pins),
                    polylines: _routePolylines,
                    onMapCreated: _onMapCreated,
                    onCameraMove: (cp) => _mapContextTarget = cp.target,
                    onTap: (pos) => _addPinAt(pos),
                  ),
                  if (_routePolylines.isNotEmpty)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Material(
                        color: Colors.white,
                        elevation: 3,
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: context.t('routePlanClearRoute'),
                          onPressed: _clearPlannedRoute,
                          icon: const Icon(Icons.close),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
            ],
          );
        },
      ),
    );
  }
}

class _BusStop {
  final double lat;
  final double lng;
  final String name;

  const _BusStop({
    required this.lat,
    required this.lng,
    required this.name,
  });
}

class _TaxiOption {
  final String name;
  final String short;
  final Color color;
  final Uri appUri;
  final Uri? webUri;

  const _TaxiOption({
    required this.name,
    required this.short,
    required this.color,
    required this.appUri,
    this.webUri,
  });
}

/// Rota planlayıcı: yazarken altta adres önerileri.
class _RoutePlannerSheet extends StatefulWidget {
  const _RoutePlannerSheet({
    required this.controller,
    required this.geocodingService,
    required this.mapContextTarget,
    required this.pins,
    required this.onAnalyze,
  });

  final TextEditingController controller;
  final GeocodingService geocodingService;
  final LatLng? mapContextTarget;
  final List<SafetyPin> pins;
  final void Function(String query, LatLng? pickedLatLng) onAnalyze;

  @override
  State<_RoutePlannerSheet> createState() => _RoutePlannerSheetState();
}

class _RoutePlannerSheetState extends State<_RoutePlannerSheet> {
  Timer? _debounce;
  List<AddressSuggestion> _suggestions = [];
  bool _loading = false;
  LatLng? _pickedLatLng;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    setState(() => _pickedLatLng = null);
    _scheduleSearch(widget.controller.text);
  }

  void _scheduleSearch(String raw) {
    _debounce?.cancel();
    final q = raw.trim();
    if (q.length < 2) {
      setState(() {
        _loading = false;
        _suggestions = [];
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () => _fetch(q));
  }

  Future<void> _fetch(String q) async {
    setState(() => _loading = true);
    String? localityHint;
    String? adminHint;
    final target = widget.mapContextTarget;
    if (target != null) {
      try {
        final places = await placemarkFromCoordinates(
          target.latitude,
          target.longitude,
        );
        if (places.isNotEmpty) {
          final p = places.first;
          localityHint = p.subAdministrativeArea ?? p.locality;
          adminHint = p.administrativeArea;
        }
      } catch (_) {}
    }

    final list = await widget.geocodingService.searchAddressSuggestions(
      q,
      localityHint: localityHint,
      adminHint: adminHint,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _suggestions = list;
    });
  }

  void _pick(AddressSuggestion s) {
    widget.controller.text = s.title;
    _pickedLatLng = s.latLng;
    setState(() => _suggestions = []);
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context).bottom;
    final viewInset = MediaQuery.viewInsetsOf(context).bottom;
    final showList = _loading || _suggestions.isNotEmpty;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + pad + viewInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.t('routePlanSheetTitle'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF241247),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            context.t('routePlanSheetBody'),
            style: TextStyle(
              color: Colors.grey.shade800,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: widget.controller,
            textInputAction: TextInputAction.search,
            onSubmitted: (v) {
              final q = v.trim();
              if (q.isEmpty) return;
              widget.onAnalyze(q, _pickedLatLng);
            },
            decoration: InputDecoration(
              labelText: context.t('routePlanDestinationHint'),
              border: const OutlineInputBorder(),
              suffixIcon: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : (widget.controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            widget.controller.clear();
                            setState(() {
                              _suggestions = [];
                              _pickedLatLng = null;
                            });
                          },
                        )
                      : null),
            ),
          ),
          if (showList) ...[
            const SizedBox(height: 8),
            Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFFF8F7FC),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: _loading && _suggestions.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              context.t('routePlanSuggestionsLoading'),
                              style: TextStyle(color: Colors.grey.shade800),
                            ),
                          ],
                        ),
                      )
                    : (_suggestions.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(14),
                            child: Text(
                              context.t('routePlanSuggestionsEmpty'),
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 13,
                              ),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: _suggestions.length,
                            separatorBuilder: (_, _) => Divider(
                              height: 1,
                              color: Colors.grey.shade300,
                            ),
                            itemBuilder: (context, i) {
                              final s = _suggestions[i];
                              return ListTile(
                                dense: true,
                                leading: Icon(
                                  Icons.place_outlined,
                                  color: Colors.grey.shade700,
                                ),
                                title: Text(
                                  s.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: s.subtitle == null
                                    ? null
                                    : Text(
                                        s.subtitle!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                onTap: () => _pick(s),
                              );
                            },
                          )),
              ),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () {
              final q = widget.controller.text.trim();
              if (q.isEmpty) return;
              widget.onAnalyze(q, _pickedLatLng);
            },
            child: Text(context.t('routePlanAnalyze')),
          ),
        ],
      ),
    );
  }
}

