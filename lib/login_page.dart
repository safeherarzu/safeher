import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {

  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _emailController =
      TextEditingController();

  final TextEditingController _passwordController =
      TextEditingController();

  bool _isLoading = false;

  Future<void> _login() async {

    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {

      _showMessage("Email ve şifre boş olamaz");
      return;
    }

    setState(() => _isLoading = true);

    try {

      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

    } on FirebaseAuthException catch (e) {

      _showMessage(e.message ?? "Giriş başarısız");

    } catch (e) {

      _showMessage("Bilinmeyen hata oluştu");

    }

    setState(() => _isLoading = false);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// 🔐 Şifre sıfırlama dialog
  void _showResetDialog() {

    TextEditingController emailController =
        TextEditingController();

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Şifre Sıfırla"),

          content: TextField(
            controller: emailController,
            decoration: const InputDecoration(
              labelText: "Email",
            ),
          ),

          actions: [

            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("İptal"),
            ),

            ElevatedButton(
              onPressed: () async {

                final email =
                    emailController.text.trim();

                if (email.isEmpty) {
                  _showMessage("Email giriniz");
                  return;
                }

                try {

                  await FirebaseAuth.instance
                      .sendPasswordResetEmail(
                          email: email);

                  Navigator.pop(context);

                  _showMessage(
                      "Şifre sıfırlama maili gönderildi");

                } catch (e) {

                  _showMessage(
                      "Mail gönderilemedi");
                }
              },
              child: const Text("Gönder"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      body: Container(

        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF6C5CE7),
              Color(0xFFA29BFE)
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),

        child: Center(

          child: SingleChildScrollView(

            padding: const EdgeInsets.all(24),

            child: Card(

              elevation: 8,

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),

              child: Padding(

                padding: const EdgeInsets.all(24),

                child: Column(

                  mainAxisSize: MainAxisSize.min,

                  children: [

                    Image.asset(
                      "assets/logo.png",
                      height: 70,
                    ),

                    const SizedBox(height: 10),

                    const Text(
                      "SafeHer",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 25),

                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: "Email",
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 15),

                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: "Şifre",
                        border: OutlineInputBorder(),
                      ),
                    ),

                    /// 🔐 Şifremi unuttum
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _showResetDialog,
                        child: const Text("Şifremi unuttum"),
                      ),
                    ),

                    const SizedBox(height: 10),

                    _isLoading
                        ? const CircularProgressIndicator(
                            color: Color(0xFF6C5CE7),
                          )
                        : SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _login,
                              child: const Text("Giriş Yap"),
                            ),
                          ),

                    const SizedBox(height: 10),

                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [

                        const Text("Hesabın yok mu?"),

                        TextButton(
                          onPressed: () {

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const RegisterPage(),
                              ),
                            );

                          },
                          child: const Text("Kayıt Ol"),
                        )

                      ],
                    )

                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}