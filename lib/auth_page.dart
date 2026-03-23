import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main_screen.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _emailController =
      TextEditingController();
  final TextEditingController _passwordController =
      TextEditingController();

  bool isLogin = true;
  bool isLoading = false;

  Future<void> _submit() async {
    setState(() => isLoading = true);

    try {
      UserCredential userCredential;

      if (isLogin) {
        // Giriş
        userCredential =
            await _auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password:
              _passwordController.text.trim(),
        );
      } else {
        // Kayıt
        userCredential =
            await _auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password:
              _passwordController.text.trim(),
        );

        // Users koleksiyonuna kayıt oluştur
        await _firestore
            .collection("users")
            .doc(userCredential.user!.uid)
            .set({
          "createdAt": Timestamp.now(),
        });
      }

      // 🔥 Giriş başarılıysa MainScreen'e git
      if (!mounted) return;
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("HATA: ${e.code}")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("GENEL HATA: $e")),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isLogin ? "Giriş Yap" : "Kayıt Ol"),
        backgroundColor: Colors.pink,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration:
                  const InputDecoration(labelText: "Email"),
            ),
            TextField(
              controller: _passwordController,
              decoration:
                  const InputDecoration(labelText: "Şifre"),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink,
                    ),
                    onPressed: _submit,
                    child: Text(isLogin
                        ? "Giriş Yap"
                        : "Kayıt Ol"),
                  ),
            TextButton(
              onPressed: () {
                setState(() {
                  isLogin = !isLogin;
                });
              },
              child: Text(
                isLogin
                    ? "Hesabın yok mu? Kayıt ol"
                    : "Zaten hesabın var mı? Giriş yap",
              ),
            )
          ],
        ),
      ),
    );
  }
}