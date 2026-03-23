import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {

  int totalSafe = 0;
  int totalUnsafe = 0;
  int myContributions = 0;
  int totalSOS = 0;

  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {

    // Toplam bölgeler
    final locationsSnapshot =
        await FirebaseFirestore.instance
            .collection("locations")
            .get();

    int safe = 0;
    int unsafe = 0;
    int mine = 0;

    for (var doc in locationsSnapshot.docs) {

      var data = doc.data();

      if (data["type"] == "safe") safe++;
      if (data["type"] == "unsafe") unsafe++;

      if (data["userId"] == user!.uid) mine++;
    }

    // SOS sayısı
    final sosSnapshot =
        await FirebaseFirestore.instance
            .collection("sos_logs")
            .where("userId",
                isEqualTo: user!.uid)
            .get();

    setState(() {
      totalSafe = safe;
      totalUnsafe = unsafe;
      myContributions = mine;
      totalSOS = sosSnapshot.docs.length;
    });
  }

  Widget statCard(String title, int value, Color color) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(
                  fontSize: 16),
            ),
            const SizedBox(height: 10),
            Text(
              value.toString(),
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: color),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text("İstatistikler"),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [

            statCard("🟢 Güvenli Bölgeler",
                totalSafe,
                Colors.green),

            statCard("🔴 Güvensiz Bölgeler",
                totalUnsafe,
                Colors.red),

            statCard("👤 Benim Katkılarım",
                myContributions,
                Colors.blue),

            statCard("🚨 Gönderdiğim SOS",
                totalSOS,
                Colors.orange),

          ],
        ),
      ),
    );
  }
}
