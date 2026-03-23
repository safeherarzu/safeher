import 'package:flutter/material.dart';
import 'main_screen.dart';

class NotificationDetailPage extends StatelessWidget {
  final Map<String, dynamic> data;

  const NotificationDetailPage({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final lat = data["lat"];
    final lng = data["lng"];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Bildirim Detayı"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "SOS Bildirimi",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Text("Lat: $lat"),
            Text("Lng: $lng"),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MainScreen(
                        initialIndex: 0,
                        focusLat: lat,
                        focusLng: lng,
                      ),
                    ),
                    (route) => false,
                  );
                },
                child: const Text("Haritada Göster"),
              ),
            )
          ],
        ),
      ),
    );
  }
}