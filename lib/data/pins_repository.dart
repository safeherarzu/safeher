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

  /// Yeni pin ekler; Firestore belge kimliğini döner.
  Future<String> addPin({
    required double lat,
    required double lng,
    required bool isSafe,
    required List<String> tags,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw StateError('Kullanıcı oturumu yok.');
    }
    final ref = await _firestore.collection('locations').add({
      'lat': lat,
      'lng': lng,
      'type': isSafe ? 'safe' : 'danger',
      'tags': tags,
      'likes': 0,
      'dislikes': 0,
      'userId': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw StateError('Kullanıcı oturumu yok.');
    }
    final doc = await _firestore.collection('locations').doc(pinId).get();
    if (!doc.exists) {
      throw StateError('İşaret bulunamadı.');
    }
    final owner = doc.data()?['userId'] as String?;
    if (owner != null && owner != uid) {
      throw StateError('Bu işareti yalnızca ekleyen kullanıcı silebilir.');
    }
    await _firestore.collection('locations').doc(pinId).delete();
  }
}

