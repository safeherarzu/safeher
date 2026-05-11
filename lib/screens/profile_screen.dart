import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import 'settings_menu_screen.dart';
import '../services/emergency_contacts_repository.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final EmergencyContactsRepository _contactsRepo =
      EmergencyContactsRepository();

  List<String> _contacts = const [];
  bool _contactsLoading = true;
  bool _deletingAccount = false;

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

  Future<void> _deleteUserOwnedDocs(String uid) async {
    final firestore = FirebaseFirestore.instance;
    final collections = <String>['users', 'emergency_contacts', 'sos_logs', 'locations'];

    for (final collection in collections) {
      final query = collection == 'users'
          ? await firestore
              .collection(collection)
              .where(FieldPath.documentId, isEqualTo: uid)
              .limit(1)
              .get()
          : await firestore
              .collection(collection)
              .where('userId', isEqualTo: uid)
              .limit(100)
              .get();

      if (query.docs.isEmpty) continue;
      final batch = firestore.batch();
      for (final doc in query.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  Future<String?> _askDeletePassword(BuildContext context, String email) async {
    final controller = TextEditingController();
    try {
      return showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Hesabı Sil'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$email hesabını kalıcı olarak silmek üzeresin. Bu işlem geri alınamaz.',
                ),
                const SizedBox(height: 12),
                const Text('Devam etmek için şifreni gir:'),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  autofocus: true,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Şifre',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () =>
                    Navigator.of(dialogContext).pop(controller.text),
                child: const Text('Hesabımı Sil'),
              ),
            ],
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _deleteAccount(BuildContext context) async {
    if (_deletingAccount) return;
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;
    if (user == null || email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silinecek hesap bulunamadı.')),
      );
      return;
    }

    final password = await _askDeletePassword(context, email);
    if (!context.mounted || password == null) return;
    if (password.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hesabı silmek için şifre gerekli.')),
      );
      return;
    }

    setState(() => _deletingAccount = true);
    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
      await _deleteUserOwnedDocs(user.uid);
      await _contactsRepo.clear();
      await user.delete();

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hesabın silindi.')),
      );
    } on FirebaseAuthException catch (e) {
      if (!context.mounted) return;
      final message = switch (e.code) {
        'wrong-password' || 'invalid-credential' => 'Şifre hatalı.',
        'requires-recent-login' =>
          'Güvenlik için lütfen çıkış yapıp tekrar giriş yaptıktan sonra hesabını sil.',
        _ => 'Hesap silme hatası: ${e.message ?? e.code}',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hesap silme hatası: $e')),
      );
    } finally {
      if (mounted) setState(() => _deletingAccount = false);
    }
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          child: Column(
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userEmail = user?.email ?? 'E-posta bulunamadı';

    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.pageGradient),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppTheme.actionGradient,
                    ),
                    child: const Icon(Icons.person, color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SafeHer Kullanıcısı',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userEmail,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('locations').snapshots(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? const [];
              final total = docs.length;
              final safe = docs.where((d) => (d.data()['type'] ?? 'safe') == 'safe').length;
              final danger = total - safe;

              return Row(
                children: [
                  _statCard(
                    icon: Icons.place,
                    label: 'Toplam Pin',
                    value: '$total',
                  ),
                  const SizedBox(width: 10),
                  _statCard(
                    icon: Icons.verified_user,
                    label: 'Güvenli',
                    value: '$safe',
                  ),
                  const SizedBox(width: 10),
                  _statCard(
                    icon: Icons.report_problem,
                    label: 'Güvensiz',
                    value: '$danger',
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
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
                      'Acil kişi eklenmemiş. SOS ekranından ekleyebilirsin.',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _contacts
                          .map((c) => Chip(
                                label: Text(c),
                                labelStyle: const TextStyle(
                                  color: Color(0xFF2B1654),
                                  fontWeight: FontWeight.w700,
                                ),
                                backgroundColor: const Color(0xFFEADFFF),
                                side: const BorderSide(color: Color(0xFFC9B6F8)),
                                avatar: const Icon(
                                  Icons.phone,
                                  size: 16,
                                  color: Color(0xFF5C2FA8),
                                ),
                              ))
                          .toList(),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: ListTile(
              leading: const Icon(Icons.settings, color: Colors.white),
              title: Text(
                context.t('settings'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                context.t('settingsSubtitle'),
                style: TextStyle(color: Colors.white.withValues(alpha: 0.82)),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.white),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsMenuScreen()),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: ListTile(
              enabled: !_deletingAccount,
              leading: _deletingAccount
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_forever, color: Colors.redAccent),
              title: const Text(
                'Hesabı Sil',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Text(
                'Hesabını ve hesapla ilişkili temel verileri kalıcı olarak sil',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.82)),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.redAccent),
              onTap: _deletingAccount ? null : () => _deleteAccount(context),
            ),
          ),
        ],
      ),
    );
  }
}

