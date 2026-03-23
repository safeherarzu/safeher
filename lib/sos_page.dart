import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class SosPage extends StatefulWidget {
  const SosPage({super.key});

  @override
  State<SosPage> createState() => _SosPageState();
}

class _SosPageState extends State<SosPage> {
  bool isActive = false;
  bool isLoading = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _toggleSos() async {
    if (isActive) {
      setState(() {
        isActive = false;
      });
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // 🔹 Konum servisi açık mı?
      bool serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        throw Exception("Konum servisi kapalı.");
      }

      // 🔹 İzin kontrolü
      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission =
            await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception("Konum izni verilmedi.");
      }

      // 🔹 Konum al (10 saniye timeout)
      Position position =
          await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      final user = _auth.currentUser;
      if (user == null) {
        throw Exception("Kullanıcı bulunamadı.");
      }

      // 🔥 Firestore'a SOS kaydı ekle
      await _firestore.collection("sos_logs").add({
        "lat": position.latitude,
        "lng": position.longitude,
        "userId": user.uid,
        "createdAt": Timestamp.now(),
      });

      // 🔥 Kullanıcının sosCount değerini artır
      await _firestore
          .collection("users")
          .doc(user.uid)
          .update({
        "sosCount": FieldValue.increment(1),
      });

      setState(() {
        isActive = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("SOS kaydı oluşturuldu."),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Hata: $e"),
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          isActive ? Colors.red.shade900 : Colors.white,
      appBar: AppBar(
        title: const Text("Acil Durum"),
        backgroundColor:
            isActive ? Colors.red : Colors.pink,
      ),
      body: Center(
        child: isLoading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _toggleSos,
                    child: AnimatedContainer(
                      duration:
                          const Duration(milliseconds: 300),
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive
                            ? Colors.white
                            : Colors.red,
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 20,
                            spreadRadius: 5,
                          )
                        ],
                      ),
                      child: Center(
                        child: Text(
                          isActive
                              ? "SONLANDIR"
                              : "SOS",
                          style: TextStyle(
                            color: isActive
                                ? Colors.red
                                : Colors.white,
                            fontSize: 28,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    isActive
                        ? "Acil durum aktif.\nYardım çağrıldı."
                        : "Tehlike anında\nbutona basın.",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}