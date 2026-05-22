import 'package:cloud_firestore/cloud_firestore.dart';

class SafetyPin {
  final String id;
  final double lat;
  final double lng;
  final bool isSafe;
  final List<String> tags;
  final int likes;
  final int dislikes;
  /// Firestore `userId`; null on legacy docs or local-only pins.
  final String? ownerUid;

  const SafetyPin({
    required this.id,
    required this.lat,
    required this.lng,
    required this.isSafe,
    required this.tags,
    required this.likes,
    required this.dislikes,
    this.ownerUid,
  });

  factory SafetyPin.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final type = (data['type'] ?? 'safe') as String;

    return SafetyPin(
      id: doc.id,
      lat: (data['lat'] as num?)?.toDouble() ?? 0,
      lng: (data['lng'] as num?)?.toDouble() ?? 0,
      isSafe: type == 'safe',
      tags: (data['tags'] as List<dynamic>? ?? const []).cast<String>(),
      likes: (data['likes'] as num?)?.toInt() ?? 0,
      dislikes: (data['dislikes'] as num?)?.toInt() ?? 0,
      ownerUid: _readOwnerUid(data),
    );
  }

  static String? _readOwnerUid(Map<String, dynamic> data) {
    for (final key in ['userId', 'user_id', 'ownerId', 'uid', 'firebase_uid']) {
      final v = data[key];
      if (v is String && v.isNotEmpty) return v;
    }
    return null;
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

