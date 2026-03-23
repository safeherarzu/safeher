import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EmergencyContactsPage extends StatefulWidget {
  const EmergencyContactsPage({super.key});

  @override
  State<EmergencyContactsPage> createState() =>
      _EmergencyContactsPageState();
}

class _EmergencyContactsPageState
    extends State<EmergencyContactsPage> {

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  final TextEditingController _nameController =
      TextEditingController();

  final TextEditingController _phoneController =
      TextEditingController();

  Future<void> _addContact() async {

    final user = _auth.currentUser;
    if (user == null) return;

    if (_nameController.text.isEmpty ||
        _phoneController.text.isEmpty) return;

    String phone = _phoneController.text.trim();

    if (!phone.startsWith("+")) {
      phone = "+$phone";
    }

    await _firestore
        .collection("emergency_contacts")
        .add({
      "userId": user.uid,
      "name": _nameController.text.trim(),
      "phone": phone,
      "createdAt": Timestamp.now(),
    });

    _nameController.clear();
    _phoneController.clear();

    Navigator.pop(context);
  }

  Future<void> _deleteContact(String id) async {

    await _firestore
        .collection("emergency_contacts")
        .doc(id)
        .delete();
  }

  void _showAddDialog() {

    showDialog(
      context: context,
      builder: (_) {

        return AlertDialog(
          title: const Text("Acil Kişi Ekle"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                    labelText: "İsim"),
              ),

              const SizedBox(height: 10),

              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                    labelText:
                        "Telefon (+90555...)"),
              ),
            ],
          ),
          actions: [

            TextButton(
              onPressed: () =>
                  Navigator.pop(context),
              child: const Text("İptal"),
            ),

            ElevatedButton(
              onPressed: _addContact,
              child: const Text("Kaydet"),
            ),

          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {

    final user = _auth.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text("Kullanıcı bulunamadı"),
        ),
      );
    }

    return Scaffold(

      appBar: AppBar(
        title: const Text("Acil Kişilerim"),
        backgroundColor:
            const Color(0xFF6C5CE7),
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

        child: StreamBuilder<QuerySnapshot>(

          stream: _firestore
              .collection("emergency_contacts")
              .where("userId",
                  isEqualTo: user.uid)
              .snapshots(),

          builder: (context, snapshot) {

            if (!snapshot.hasData) {
              return const Center(
                child:
                    CircularProgressIndicator(
                        color: Colors.white),
              );
            }

            final contacts =
                snapshot.data!.docs;

            if (contacts.isEmpty) {
              return const Center(
                child: Text(
                  "Henüz acil kişi eklenmedi",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18),
                ),
              );
            }

            return ListView.builder(

              itemCount: contacts.length,

              itemBuilder: (context, index) {

                final data =
                    contacts[index].data()
                        as Map<String,
                            dynamic>;

                final id =
                    contacts[index].id;

                return Card(

                  margin:
                      const EdgeInsets.all(
                          12),

                  child: ListTile(

                    leading: const Icon(
                        Icons.person,
                        color: Color(
                            0xFF6C5CE7)),

                    title: Text(
                        data["name"] ?? ""),

                    subtitle: Text(
                        data["phone"] ?? ""),

                    trailing: IconButton(
                      icon: const Icon(
                          Icons.delete,
                          color: Colors.red),
                      onPressed: () =>
                          _deleteContact(id),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),

      floatingActionButton:
          FloatingActionButton(

        backgroundColor:
            const Color(0xFF6C5CE7),

        onPressed: _showAddDialog,

        child: const Icon(Icons.add),
      ),
    );
  }
}