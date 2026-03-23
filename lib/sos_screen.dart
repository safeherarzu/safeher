import 'package:flutter/material.dart';

class SosScreen extends StatelessWidget {
  final VoidCallback onSend;
  final int contactCount;

  const SosScreen({
    super.key,
    required this.onSend,
    required this.contactCount,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade100,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.red,
                size: 100,
              ),

              const SizedBox(height: 20),

              const Text(
                "ACİL SOS",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),

              const SizedBox(height: 20),

              Text(
                "$contactCount kişiye konum gönderilecek",
                style: const TextStyle(fontSize: 16),
              ),

              const SizedBox(height: 40),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 15,
                  ),
                ),
                onPressed: () {
                  onSend();
                  Navigator.pop(context);
                },
                child: const Text(
                  "SOS GÖNDER",
                  style: TextStyle(fontSize: 18),
                ),
              ),

              const SizedBox(height: 20),

              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text("İptal"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
