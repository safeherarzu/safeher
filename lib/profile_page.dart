import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'emergency_contacts_page.dart';
import 'sos_history_page.dart';
import 'notifications_page.dart';
import 'login_page.dart';

class ProfilePage extends StatelessWidget {
  ProfilePage({super.key});

  String getBadge(int markerCount) {
    if (markerCount >= 100) return "SafeHer Elçisi";
    if (markerCount >= 50) return "Güven Lideri";
    if (markerCount >= 20) return "Güven Destekçisi";
    if (markerCount >= 5) return "Topluluk Katkıcısı";
    return "Yeni Üye";
  }

  Widget menuCard(
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 6,
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: const Color(0xFF6C5CE7),
        ),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profil"),
        backgroundColor: const Color(0xFF6C5CE7),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF6C5CE7),
              Color(0xFFA29BFE),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection("users")
              .doc(uid)
              .snapshots(),
          builder: (context, snapshot) {

            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              );
            }

            final data =
                snapshot.data!.data() as Map<String, dynamic>?;

            final email = data?["email"] ?? "";
            final sosCount = data?["sosCount"] ?? 0;
            final markerCount = data?["markerCount"] ?? 0;

            final badge = getBadge(markerCount);

            return ListView(
              children: [

                const SizedBox(height: 40),

                /// AVATAR
                const CircleAvatar(
                  radius: 45,
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.person,
                    size: 40,
                    color: Color(0xFF6C5CE7),
                  ),
                ),

                const SizedBox(height: 10),

                Center(
                  child: Text(
                    email,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                Center(
                  child: Chip(
                    backgroundColor: Colors.amber,
                    label: Text(badge),
                  ),
                ),

                const SizedBox(height: 30),

                /// MENÜLER

                menuCard(
                  Icons.contacts,
                  "Acil Kişilerim",
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const EmergencyContactsPage(),
                      ),
                    );
                  },
                ),

                menuCard(
                  Icons.history,
                  "SOS Geçmişi",
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const SosHistoryPage(),
                      ),
                    );
                  },
                ),

                menuCard(
                  Icons.notifications,
                  "Bildirimler",
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const NotificationsPage(),
                      ),
                    );
                  },
                ),

                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: ListTile(
                    leading: const Icon(
                      Icons.logout,
                      color: Colors.red,
                    ),
                    title: const Text(
                      "Çıkış Yap",
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () async {

                      await FirebaseAuth.instance.signOut();

                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LoginPage(),
                        ),
                        (route) => false,
                      );

                    },
                  ),
                ),

                const SizedBox(height: 30),

                /// İSTATİSTİKLER

                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [

                        const Text(
                          "İstatistikler",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),

                        const SizedBox(height: 10),

                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceAround,
                          children: [

                            Column(
                              children: [
                                const Text("SOS"),
                                Text(
                                  "$sosCount",
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),

                            Column(
                              children: [
                                const Text("İşaretleme"),
                                Text(
                                  "$markerCount",
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),

                          ],
                        ),

                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 40),

              ],
            );
          },
        ),
      ),
    );
  }
}