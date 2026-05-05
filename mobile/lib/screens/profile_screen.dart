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
        ],
      ),
    );
  }
}

