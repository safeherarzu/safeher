import 'package:cloud_firestore/cloud_firestore.dart';

class SafetyPin {
  final String id;
  final double lat;
  final double lng;
  final bool isSafe;
  final List<String> tags;
  final int likes;
  final int dislikes;

  const SafetyPin({
    required this.id,
    required this.lat,
    required this.lng,
    required this.isSafe,
    required this.tags,
    required this.likes,
    required this.dislikes,
  });

  factory SafetyPin.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final type = (data['type'] ?? 'safe') as String;

    return SafetyPin(
      id: doc.id,
      lat: (data['lat'] ?? 0).toDouble(),
      lng: (data['lng'] ?? 0).toDouble(),
      isSafe: type == 'safe',
      tags: (data['tags'] as List<dynamic>? ?? const []).cast<String>(),
      likes: (data['likes'] ?? 0) as int,
      dislikes: (data['dislikes'] ?? 0) as int,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'lat': lat,
      'lng': lng,
      'type': isSafe ? 'safe' : 'danger',
      'tags': tags,
      'likes': likes,
      'dislikes': dislikes,
    };
  }
}

