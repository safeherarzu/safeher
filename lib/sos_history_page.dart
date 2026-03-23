import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class SosHistoryPage extends StatelessWidget {
  const SosHistoryPage({super.key});

  Future<void> _openMap(double lat, double lng) async {
    final Uri url = Uri.parse(
      "https://www.google.com/maps/search/?api=1&query=$lat,$lng",
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text("Giriş yapılmamış"),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("SOS Geçmişi"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('sos_logs')
            .where('userId', isEqualTo: user.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text("Hata: ${snapshot.error}"),
            );
          }

          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Text("Henüz SOS geçmişi yok"),
            );
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data =
                  docs[index].data()
                      as Map<String, dynamic>;

              final double lat =
                  (data['lat'] ?? 0.0)
                      .toDouble();
              final double lng =
                  (data['lng'] ?? 0.0)
                      .toDouble();

              final Timestamp? timestamp =
                  data['createdAt'];

              final String formattedTime =
                  timestamp != null
                      ? DateFormat(
                              "dd MMM yyyy - HH:mm")
                          .format(
                              timestamp.toDate())
                      : "Zaman yok";

              return Card(
                margin:
                    const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6),
                child: ListTile(
                  leading: const Icon(
                    Icons.warning,
                    color: Colors.red,
                  ),
                  title: Text(
                      "Konum: $lat , $lng"),
                  subtitle: Text(
                      formattedTime),
                  trailing: IconButton(
                    icon: const Icon(
                        Icons.map),
                    onPressed: () =>
                        _openMap(lat, lng),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
