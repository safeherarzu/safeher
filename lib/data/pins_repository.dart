import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/safety_pin.dart';

class PinsRepository {
  PinsRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<SafetyPin>> watchPins() {
    return _firestore
        .collection('locations')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => SafetyPin.fromFirestore(doc))
          .toList();
    });
  }

  Future<void> addPin({
    required double lat,
    required double lng,
    required bool isSafe,
    required List<String> tags,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw StateError('Kullanıcı oturumu yok.');
    }
    await _firestore.collection('locations').add({
      'lat': lat,
      'lng': lng,
      'type': isSafe ? 'safe' : 'danger',
      'tags': tags,
      'likes': 0,
      'dislikes': 0,
      'userId': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> likePin(String pinId) async {
    await _firestore.collection('locations').doc(pinId).update({
      'likes': FieldValue.increment(1),
    });
  }

  Future<void> dislikePin(String pinId) async {
    await _firestore.collection('locations').doc(pinId).update({
      'dislikes': FieldValue.increment(1),
    });
  }

  Future<void> deletePin(String pinId) async {
    await _firestore.collection('locations').doc(pinId).delete();
  }
}

