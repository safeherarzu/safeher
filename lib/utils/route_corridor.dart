import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Düz rota segmentine yakınlık (metre) — gerçek yol yerine basit hat için örnekleme.
double minDistanceMetersToSegment(
  LatLng point,
  LatLng segmentStart,
  LatLng segmentEnd, {
  int steps = 36,
}) {
  var best = double.infinity;
  for (var i = 0; i <= steps; i++) {
    final t = i / steps;
    final lat = segmentStart.latitude +
        (segmentEnd.latitude - segmentStart.latitude) * t;
    final lng = segmentStart.longitude +
        (segmentEnd.longitude - segmentStart.longitude) * t;
    final d = Geolocator.distanceBetween(
      point.latitude,
      point.longitude,
      lat,
      lng,
    );
    if (d < best) best = d;
  }
  return best;
}
