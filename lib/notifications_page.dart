import 'package:flutter/material.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text("Bildirimler"),
        backgroundColor: const Color(0xFF6C5CE7),
      ),

      body: ListView(
        children: const [

          SizedBox(height: 10),

          ListTile(
            leading: Icon(Icons.notifications),
            title: Text("Yeni güvenlik bildirimi"),
            subtitle: Text("Bölgenizde yeni bir işaretleme yapıldı"),
          ),

          Divider(),

          ListTile(
            leading: Icon(Icons.warning),
            title: Text("SOS bildirimi"),
            subtitle: Text("Yakınınızda bir SOS çağrısı gönderildi"),
          ),

          Divider(),

          ListTile(
            leading: Icon(Icons.info),
            title: Text("Uygulama bildirimi"),
            subtitle: Text("SafeHer topluluğuna hoş geldiniz"),
          ),

        ],
      ),
    );
  }
}