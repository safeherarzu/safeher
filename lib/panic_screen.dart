import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vibration/vibration.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sos_history_page.dart';

class PanicScreen extends StatefulWidget {
  const PanicScreen({super.key});

  @override
  State<PanicScreen> createState() => _PanicScreenState();
}

class _PanicScreenState extends State<PanicScreen> {

  int countdown = 15;
  Timer? timer;
  bool success = false;
  bool blocked = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt("last_sos_time");

    if (last != null &&
        DateTime.now()
                .difference(DateTime.fromMillisecondsSinceEpoch(last))
                .inSeconds <
            60) {
      setState(() => blocked = true);
      return;
    }

    _startCountdown();
    _vibrate();
  }

  void _startCountdown() {
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (countdown == 0) {
        t.cancel();
        _sendSOS();
      } else {
        setState(() => countdown--);
      }
    });
  }

  Future<void> _vibrate() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 500);
    }
  }

  Future<Position> _getLocation() async {
    await Geolocator.requestPermission();

    return await Geolocator.getCurrentPosition(
      timeLimit: const Duration(seconds: 10),
    );
  }

  Future<void> _sendSOS() async {

    try {

      final pos = await _getLocation();
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final lat = pos.latitude;
      final lng = pos.longitude;

      await FirebaseFirestore.instance.collection("sos_logs").add({
        "userId": user.uid,
        "lat": lat,
        "lng": lng,
        "createdAt": Timestamp.now(),
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
          "last_sos_time", DateTime.now().millisecondsSinceEpoch);

      final message =
          "🚨 SOS!\nKonumum:\nhttps://maps.google.com/?q=$lat,$lng";

      final contacts = await FirebaseFirestore.instance
          .collection("emergency_contacts")
          .where("userId", isEqualTo: user.uid)
          .get();

      for (var doc in contacts.docs) {
        String phone = (doc["phone"] ?? "").replaceAll("+", "");

        final url = Uri.parse(
            "https://wa.me/$phone?text=${Uri.encodeComponent(message)}");

        await launchUrl(url, mode: LaunchMode.externalApplication);
      }

      setState(() => success = true);

    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Hata: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {

    if (blocked) {
      return const Scaffold(
        backgroundColor: Colors.orange,
        body: Center(
          child: Text(
            "1 dakika bekleyin",
            style: TextStyle(color: Colors.white, fontSize: 20),
          ),
        ),
      );
    }

    if (success) {
      return Scaffold(
        backgroundColor: Colors.green,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              const Icon(Icons.check_circle,
                  color: Colors.white, size: 100),

              const SizedBox(height: 20),

              const Text(
                "SOS GÖNDERİLDİ",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 30),

              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SosHistoryPage()),
                  );
                },
                child: const Text("Geçmiş"),
              )
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF6C5CE7),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            const Icon(Icons.warning,
                size: 80, color: Colors.white),

            const SizedBox(height: 20),

            const Text(
              "SOS GÖNDERİLİYOR",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 40),

            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Text(
                "$countdown",
                key: ValueKey(countdown),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 80,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 40),

            ElevatedButton(
              onPressed: () {
                timer?.cancel();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
              ),
              child: const Text("İPTAL",
                  style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }
}