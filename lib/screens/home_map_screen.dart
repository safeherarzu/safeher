import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../data/pins_repository.dart';
import '../models/safety_pin.dart';
import '../services/geocoding_service.dart';
import '../theme/app_theme.dart';

class HomeMapScreen extends StatefulWidget {
  const HomeMapScreen({super.key});

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

  final TextEditingController _searchController = TextEditingController();
  GoogleMapController? _mapController;
  LatLng? _pendingCameraTarget;
  LatLng? _mapContextTarget;
  bool _myLocationEnabled = false;
  final List<SafetyPin> _offlinePins = [];
  int _offlineId = 0;
  DateTime? _lastPinCreatedAt;
  Set<Marker> _busStopMarkers = <Marker>{};
  Set<Marker> _healthMarkers = <Marker>{};
  bool _isFindingHospitals = false;
  bool _isFindingPharmacies = false;
  bool _didAutoCenterOnLaunch = false;

  @override
  void initState() {
    super.initState();
    _initUserLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
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
            CameraUpdate.newLatLngZoom(target, 14),
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
          CameraUpdate.newLatLngZoom(target, 14),
        );
      } else {
        _pendingCameraTarget = target;
      }
    } catch (_) {
      // Ignore silently; user can still search or use map manually.
    }
  }

  Set<Marker> _markersFromPins(List<SafetyPin> pins) {
    final allPins = [...pins, ..._offlinePins];
    final pinMarkers = allPins
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
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      ).timeout(const Duration(seconds: 10));
    } catch (_) {
      return null;
    }
  }

  Future<void> _openNearbyBusStops() async {
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
    final nearby = await _fetchNearbyBusStops(lat, lng);
    if (!mounted) return;

    if (nearby.isEmpty) {
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${nearby.length} durak haritada gösteriliyor.')),
    );
  }

  Future<List<_BusStop>> _fetchNearbyBusStops(double lat, double lng) async {
    try {
      final query = '''
[out:json][timeout:20];
(
  node["highway"="bus_stop"](around:1200,$lat,$lng);
  way["highway"="bus_stop"](around:1200,$lat,$lng);
  relation["highway"="bus_stop"](around:1200,$lat,$lng);
  node["public_transport"="platform"](around:1200,$lat,$lng);
  way["public_transport"="platform"](around:1200,$lat,$lng);
  relation["public_transport"="platform"](around:1200,$lat,$lng);
  node["amenity"="bus_station"](around:2500,$lat,$lng);
  way["amenity"="bus_station"](around:2500,$lat,$lng);
  relation["amenity"="bus_station"](around:2500,$lat,$lng);
);
out center 80;
''';
      final res = await http.post(
        Uri.parse('https://overpass-api.de/api/interpreter'),
        body: {'data': query},
      );
      if (res.statusCode != 200) return const [];
      final map = jsonDecode(res.body) as Map<String, dynamic>;
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

  Future<List<_BusStop>> _fetchNearbyPlaces({
    required double lat,
    required double lng,
    required String overpassFilter,
    required int radius,
  }) async {
    try {
      final query = '''
[out:json][timeout:20];
(
  node[$overpassFilter](around:$radius,$lat,$lng);
  way[$overpassFilter](around:$radius,$lat,$lng);
  relation[$overpassFilter](around:$radius,$lat,$lng);
);
out center 60;
''';
      final res = await http
          .post(
            Uri.parse('https://overpass-api.de/api/interpreter'),
            body: {'data': query},
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return const [];
      final map = jsonDecode(res.body) as Map<String, dynamic>;
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

  Future<List<_BusStop>> _fetchNearestPlacesFast({
    required double lat,
    required double lng,
    required String overpassFilter,
    required int radius,
    required int maxResults,
  }) async {
    final results = await _fetchNearbyPlaces(
      lat: lat,
      lng: lng,
      overpassFilter: overpassFilter,
      radius: radius,
    );
    if (results.isEmpty) return const [];

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
    return deduped.take(maxResults).toList();
  }

  Future<List<_BusStop>> _fetchNearestPlacesWithExpansion({
    required double lat,
    required double lng,
    required String overpassFilter,
    required List<int> radii,
    required int maxResults,
  }) async {
    for (final r in radii) {
      final results = await _fetchNearbyPlaces(
        lat: lat,
        lng: lng,
        overpassFilter: overpassFilter,
        radius: r,
      );
      if (results.isNotEmpty) {
        final sorted = [...results]
          ..sort((a, b) {
            final da = _distanceMeters(lat, lng, a.lat, a.lng);
            final db = _distanceMeters(lat, lng, b.lat, b.lng);
            return da.compareTo(db);
          });
        return sorted.take(maxResults).toList();
      }
    }
    return const [];
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

  Future<void> _showNearbyHospitals() async {
    if (_isFindingHospitals) return;
    _isFindingHospitals = true;
    final target = await _resolveTargetForNearby();
    if (!mounted) return;
    if (target == null) {
      _isFindingHospitals = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Konum alınamadı. Lütfen konum iznini ve GPS’i açın.'),
        ),
      );
      return;
    }

    var hospitals = await _fetchNearestPlacesFast(
      lat: target.latitude,
      lng: target.longitude,
      overpassFilter: '"amenity"="hospital"',
      radius: 12000,
      maxResults: 8,
    );
    if (hospitals.isEmpty) {
      hospitals = await _fetchNearestPlacesWithExpansion(
        lat: target.latitude,
        lng: target.longitude,
        overpassFilter: '"amenity"="hospital"',
      radii: const [2500, 5000, 10000, 20000],
      maxResults: 8,
      );
    }
    if (!mounted) return;
    if (hospitals.isEmpty) {
      _isFindingHospitals = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yakında hastane bulunamadı.')),
      );
      return;
    }

    setState(() {
      _healthMarkers = {
        ..._healthMarkers.where(
          (m) => !m.markerId.value.startsWith('hospital_'),
        ),
        ...hospitals.map(
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
    final first = hospitals.first;
    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(first.lat, first.lng), 14),
    );
    _isFindingHospitals = false;
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${hospitals.length} hastane haritada (en yakınlar) gösteriliyor.'),
        ),
      );
  }

  Future<void> _showNearbyPharmacies() async {
    if (_isFindingPharmacies) return;
    _isFindingPharmacies = true;
    final target = await _resolveTargetForNearby();
    if (!mounted) return;
    if (target == null) {
      _isFindingPharmacies = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Konum alınamadı. Lütfen konum iznini ve GPS’i açın.'),
        ),
      );
      return;
    }

    var pharmacies = await _fetchNearestPlacesFast(
      lat: target.latitude,
      lng: target.longitude,
      overpassFilter: '"amenity"="pharmacy"',
      radius: 8000,
      maxResults: 10,
    );
    if (pharmacies.isEmpty) {
      pharmacies = await _fetchNearestPlacesWithExpansion(
        lat: target.latitude,
        lng: target.longitude,
        overpassFilter: '"amenity"="pharmacy"',
        radii: const [1800, 4000, 8000, 15000],
        maxResults: 10,
      );
    }
    if (!mounted) return;
    if (pharmacies.isEmpty) {
      _isFindingPharmacies = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yakında eczane bulunamadı.')),
      );
      return;
    }

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
    _isFindingPharmacies = false;
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${pharmacies.length} eczane haritada (en yakınlar) gösteriliyor.'),
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
    if (_mapContextTarget != null) return _mapContextTarget;
    final pos = await _tryGetCurrentPosition();
    if (pos == null) return null;
    return LatLng(pos.latitude, pos.longitude);
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
        CameraUpdate.newLatLngZoom(target, 14),
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
                              await _pinsRepository.addPin(
                                lat: position.latitude,
                                lng: position.longitude,
                                isSafe: safe,
                                tags: selectedTags.toList(),
                              );
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
    // Bottom sheet UI, senin örnekteki stile benzer şekilde: etiketler + like/dislike + sil.
    if (!context.mounted) return;

    int likes = pin.likes;
    int dislikes = pin.dislikes;

    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final isSafe = pin.isSafe;

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Kullanıcı Rozeti',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  const Row(
                    children: [
                      Icon(Icons.person),
                      SizedBox(width: 6),
                      Text('Yeni Üye'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  Row(
                    children: [
                      Icon(
                        Icons.circle,
                        color: isSafe ? Colors.green : Colors.red,
                        size: 12,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isSafe ? 'Güvenli Bölge' : 'Güvensiz Bölge',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: pin.tags.isEmpty
                        ? const [
                            Chip(label: Text('Etiket yok')),
                          ]
                        : pin.tags.map((t) => Chip(label: Text(t))).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.thumb_up, color: Colors.green),
                        onPressed: () async {
                          if (_isOfflinePin(pin)) {
                            setState(() => likes += 1);
                            return;
                          }
                          await _pinsRepository.likePin(pin.id);
                          setState(() => likes += 1);
                        },
                      ),
                      Text('$likes'),
                      const SizedBox(width: 20),
                      IconButton(
                        icon: const Icon(Icons.thumb_down, color: Colors.red),
                        onPressed: () async {
                          if (_isOfflinePin(pin)) {
                            setState(() => dislikes += 1);
                            return;
                          }
                          await _pinsRepository.dislikePin(pin.id);
                          setState(() => dislikes += 1);
                        },
                      ),
                      Text('$dislikes'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Güven Skoru: ${likes - dislikes}',
                    style: const TextStyle(color: Colors.red),
                  ),
                  Text(
                    'Topluluk Değerlendirmesi: ${_getScoreText(likes, dislikes)}',
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () async {
                        if (_isOfflinePin(pin)) {
                          setState(() {
                            _offlinePins.removeWhere((p) => p.id == pin.id);
                          });
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          return;
                        }
                        await _pinsRepository.deletePin(pin.id);
                        if (!context.mounted) return;
                        Navigator.pop(context);
                      },
                      child: const Text('Sil'),
                    ),
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
      child: Column(
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
                          onPressed: _openNearbyBusStops,
                          icon: const Icon(Icons.directions_bus),
                          label: const Text('Yakındaki Otobüsler'),
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
                          icon: const Icon(Icons.local_hospital),
                          label: Text(
                            _isFindingHospitals
                                ? 'Hastaneler aranıyor...'
                                : 'Yakındaki Hastaneler',
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
                          icon: const Icon(Icons.local_pharmacy),
                          label: Text(
                            _isFindingPharmacies
                                ? 'Eczaneler aranıyor...'
                                : 'Yakındaki Eczaneler',
                          ),
                        ),
                      ),
                    ],
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
              child: StreamBuilder<List<SafetyPin>>(
                stream: _pinsRepository.watchPins(),
                builder: (context, snapshot) {
                  final pins = snapshot.data ?? const <SafetyPin>[];
                  final markers = _markersFromPins(pins);

                  return GoogleMap(
                    initialCameraPosition: const CameraPosition(
                      target: LatLng(41.0082, 28.9784),
                      zoom: 12,
                    ),
                    myLocationEnabled: _myLocationEnabled,
                    markers: markers,
                    onMapCreated: _onMapCreated,
                    onCameraMove: (cp) => _mapContextTarget = cp.target,
                    onTap: (pos) => _addPinAt(pos),
                  );
                },
              ),
            ),
          ),
        ],
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

