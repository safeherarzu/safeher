import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'onboarding_page.dart';
import 'main_screen.dart';
import 'theme.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'login_page.dart';

vvoid main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  // 🔔 İZİN İSTE
  await FirebaseMessaging.instance.requestPermission();

  // 🔔 TOPIC'E ABONE OL
  await FirebaseMessaging.instance.subscribeToTopic("safeher");

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeHer',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: FutureBuilder(
        future: SharedPreferences.getInstance(),
        builder: (context, snapshot) {

          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          final prefs = snapshot.data!;
          bool seen = prefs.getBool("seenOnboarding") ?? false;

          if (seen) {
            return const AuthWrapper();
          }

          return const OnboardingPage();
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  Future<void> _createUserDocument(User user) async {
    final userDoc =
        FirebaseFirestore.instance.collection("users").doc(user.uid);

    final snapshot = await userDoc.get();

    if (!snapshot.exists) {
      await userDoc.set({
        "safeCount": 0,
        "unsafeCount": 0,
        "totalUpVotes": 0,
        "totalDownVotes": 0,
        "sosCount": 0,
        "createdAt": Timestamp.now(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          _createUserDocument(snapshot.data!);
          return const MainScreen();
        }

        return const LoginPage();
      },
    );
  }
}