import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/emergency_contacts_repository.dart';
import '../theme/app_theme.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final EmergencyContactsRepository _contactsRepo =
      EmergencyContactsRepository();

  List<String> _contacts = const [];
  bool _contactsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final contacts = await _contactsRepo.getAll();
    if (!mounted) return;
    setState(() {
      _contacts = contacts;
      _contactsLoading = false;
    });
  }

  Future<void> _sendPasswordReset(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;
    if (email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('E-posta bilgisi bulunamadı.')),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Şifre yenileme bağlantısı gönderildi: $email')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İşlem hatası: $e')),
      );
    }
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!context.mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Çıkış yapıldı.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Çıkış hatası: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? 'E-posta bulunamadı';
    final uid = user?.uid ?? '-';

    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.pageGradient),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Hesabım'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hesap Bilgileri',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'E-posta: $email',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.92)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Kullanıcı ID: $uid',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Acil Kişilerim',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_contactsLoading)
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else if (_contacts.isEmpty)
                      Text(
                        'Henüz acil kişi eklenmemiş.',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _contacts
                            .map(
                              (c) => Chip(
                                label: Text(c),
                                labelStyle: const TextStyle(
                                  color: Color(0xFF2B1654),
                                  fontWeight: FontWeight.w700,
                                ),
                                backgroundColor: const Color(0xFFEADFFF),
                                side: const BorderSide(color: Color(0xFFC9B6F8)),
                                avatar: const Icon(Icons.phone, size: 16),
                                deleteIcon: const Icon(Icons.close),
                                deleteIconColor: const Color(0xFF5C2FA8),
                                onDeleted: () async {
                                  await _contactsRepo.remove(c);
                                  await _loadContacts();
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        context.t('sosContactRemovedSnack'),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            )
                            .toList(),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.lock_reset, color: Colors.white),
                    title: const Text(
                      'Şifreyi Yenile',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      'Kayıtlı e-postana yenileme bağlantısı gönder',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.82)),
                    ),
                    onTap: () => _sendPasswordReset(context),
                  ),
                  const Divider(color: Colors.white24),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.white),
                    title: const Text(
                      'Çıkış Yap',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      'Bu cihazdaki oturumu kapat',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.82)),
                    ),
                    onTap: () => _signOut(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

