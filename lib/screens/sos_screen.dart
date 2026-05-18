import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_strings.dart';
import '../services/emergency_contacts_repository.dart';
import '../theme/app_theme.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key, this.visible = true});

  /// SOS sekmesi görünür değilken alarm çalmamalı (IndexedStack sekmeleri dispose etmez).
  final bool visible;

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  static const _alarmDurationKey = 'sosAlarmDurationSec';
  static const _alarmUseAlarmStreamKey = 'sosAlarmUseAlarmStream';

  final EmergencyContactsRepository _contactsRepo =
      EmergencyContactsRepository();

  final TextEditingController _phoneController = TextEditingController();

  List<String> _contacts = const [];
  bool _loadingContacts = true;

  Timer? _holdTimer;
  bool _holdTriggered = false;
  bool _sending = false;
  Timer? _holdCountdownTimer;
  bool _holding = false;
  int _holdSecondsLeft = 2;
  Timer? _alarmStopTimer;
  int _alarmDurationSec = 8;
  bool _alarmUseAlarmStream = true;

  @override
  void initState() {
    super.initState();
    _reloadContacts();
    _loadAlarmSettings();
  }

  @override
  void didUpdateWidget(covariant SosScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible && !widget.visible) {
      _alarmStopTimer?.cancel();
      _alarmStopTimer = null;
      _holdTimer?.cancel();
      _holdTimer = null;
      _holdCountdownTimer?.cancel();
      _holdCountdownTimer = null;
      _holding = false;
      _holdSecondsLeft = 2;
      FlutterRingtonePlayer().stop();
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _holdCountdownTimer?.cancel();
    _alarmStopTimer?.cancel();
    FlutterRingtonePlayer().stop();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _reloadContacts() async {
    setState(() => _loadingContacts = true);
    _contacts = await _contactsRepo.getAll();
    setState(() => _loadingContacts = false);
  }

  Future<void> _loadAlarmSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final duration = prefs.getInt(_alarmDurationKey) ?? 8;
    final asAlarm = prefs.getBool(_alarmUseAlarmStreamKey) ?? true;
    if (!mounted) return;
    setState(() {
      _alarmDurationSec = duration;
      _alarmUseAlarmStream = asAlarm;
    });
  }

  Future<void> _setAlarmDuration(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_alarmDurationKey, value);
    if (!mounted) return;
    setState(() => _alarmDurationSec = value);
  }

  Future<void> _setAlarmMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_alarmUseAlarmStreamKey, value);
    if (!mounted) return;
    setState(() => _alarmUseAlarmStream = value);
  }

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  }

  Future<void> _addContact() async {
    final input = _phoneController.text.trim();
    if (input.isEmpty) return;

    await _contactsRepo.add(input);
    _phoneController.clear();
    _dismissKeyboard();
    if (!mounted) return;
    await _reloadContacts();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.t('sosContactAdded'))),
    );
  }

  Future<void> _pickFromContacts() async {
    if (!mounted) return;
    try {
      final granted =
          await FlutterContacts.requestPermission(readonly: true);
      if (!granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('sosContactsPermissionNeeded'))),
        );
        return;
      }

      final contact = await FlutterContacts.openExternalPick();
      if (!mounted) return;
      if (contact == null) return;

      String? raw;
      for (final p in contact.phones) {
        final n = p.number.trim();
        if (n.isNotEmpty) {
          raw = n;
          break;
        }
      }
      if (raw == null || raw.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('sosContactNoPhone'))),
        );
        return;
      }

      final normalized = EmergencyContactsRepository.normalizePhone(raw);
      if (normalized.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('sosNumberUnreadable'))),
        );
        return;
      }

      await _contactsRepo.add(normalized);
      await _reloadContacts();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tReplace('sosAddedFromContacts', {'phone': normalized}),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tReplace('sosContactBookError', {'error': '$e'}),
          ),
        ),
      );
    }
  }

  Future<void> _sendWhatsAppWithLocation() async {
    if (!widget.visible) {
      _stopSosAlarm();
      return;
    }
    if (_sending) return;
    if (_contacts.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('sosAddContactsFirst'))),
      );
      return;
    }

    setState(() => _sending = true);
    if (widget.visible) {
      _playSosAlarm();
    }
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied ||
            requested == LocationPermission.deniedForever) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.t('sosLocationDenied'))),
          );
          return;
        }
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
        ),
      ).timeout(const Duration(seconds: 10));

      final lat = pos.latitude;
      final lng = pos.longitude;
      final mapsLink = 'https://maps.google.com/?q=$lat,$lng';
      if (!mounted) return;
      final message = context.tReplace('sosWhatsAppBody', {'url': mapsLink});

      for (final phone in _contacts) {
        final url = Uri.parse(
          'https://wa.me/$phone?text=${Uri.encodeComponent(message)}',
        );
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('sosWhatsAppSent'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tReplace('sosSendError', {'error': '$e'}),
          ),
        ),
      );
    } finally {
      _stopSosAlarm();
      if (mounted) setState(() => _sending = false);
    }
  }

  void _playSosAlarm() {
    if (!widget.visible) return;
    _alarmStopTimer?.cancel();
    try {
      FlutterRingtonePlayer().playAlarm(
        looping: true,
        asAlarm: _alarmUseAlarmStream,
        volume: 1,
      );
    } catch (_) {
      FlutterRingtonePlayer().play(
        android: AndroidSounds.alarm,
        ios: IosSounds.alarm,
        looping: true,
        volume: 1,
        asAlarm: false,
      );
    }
    _alarmStopTimer = Timer(Duration(seconds: _alarmDurationSec), _stopSosAlarm);
  }

  void _stopSosAlarm() {
    _alarmStopTimer?.cancel();
    _alarmStopTimer = null;
    FlutterRingtonePlayer().stop();
  }

  void _startHold() {
    if (!widget.visible) return;
    _holdTriggered = false;
    _holdTimer?.cancel();
    _holdCountdownTimer?.cancel();

    _holding = true;
    _holdSecondsLeft = 2;

    final startedAt = DateTime.now();
    _holdCountdownTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final elapsed = DateTime.now().difference(startedAt);
      final left = 2 - elapsed.inMilliseconds ~/ 1000;
      if (!mounted) return;
      setState(() {
        _holdSecondsLeft = left <= 0 ? 0 : left;
      });
    });

    _holdTimer = Timer(const Duration(seconds: 2), () async {
      _holdTriggered = true;
      _holdCountdownTimer?.cancel();
      _holdCountdownTimer = null;
      if (mounted) setState(() => _holding = false);
      await _sendWhatsAppWithLocation();
    });
  }

  void _cancelHold({bool showHint = true}) {
    _holdTimer?.cancel();
    _holdTimer = null;
    _holdCountdownTimer?.cancel();
    _holdCountdownTimer = null;
    _holding = false;
    _holdSecondsLeft = 2;
    if (showHint && !_holdTriggered && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('sosHoldTwoSeconds'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.pageGradient),
      child: ListView(
        padding: const EdgeInsets.all(16),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          Text(
            context.t('sosTitle'),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            context.t('sosScreenSubtitle'),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
          ),
          const SizedBox(height: 18),

          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.black12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('sosEmergencyContacts'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.done,
                        onEditingComplete: _dismissKeyboard,
                        onSubmitted: (_) => _dismissKeyboard(),
                        decoration: InputDecoration(
                          labelText: context.t('sosPhoneHint'),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _addContact,
                              child: Text(context.t('sosAddContact')),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickFromContacts,
                              icon: const Icon(Icons.contacts, size: 20),
                              label: Text(context.t('sosFromContacts')),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_loadingContacts)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else if (_contacts.isEmpty)
                    Text(
                      context.t('sosNoContactsYet'),
                      style: TextStyle(color: Colors.grey.shade800),
                    )
                  else
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: _contacts.map((phone) {
                        return Chip(
                          label: Text(phone),
                          labelStyle: const TextStyle(
                            color: Color(0xFF2B1654),
                            fontWeight: FontWeight.w700,
                          ),
                          backgroundColor: const Color(0xFFEADFFF),
                          side: const BorderSide(color: Color(0xFFC9B6F8)),
                          deleteIcon: const Icon(Icons.close),
                          deleteIconColor: const Color(0xFF5C2FA8),
                          onDeleted: () async {
                            _dismissKeyboard();
                            await _contactsRepo.remove(phone);
                            await _reloadContacts();
                          },
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 18),

          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Colors.black12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('sosAlarmSettings'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        context.t('sosDuration'),
                        style: TextStyle(color: Colors.grey.shade900),
                      ),
                      const SizedBox(width: 10),
                      DropdownButton<int>(
                        value: _alarmDurationSec,
                        items: [5, 8, 12, 20]
                            .map(
                              (s) => DropdownMenuItem<int>(
                                value: s,
                                child: Text(
                                  context.tReplace('sosSeconds', {'n': '$s'}),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) _setAlarmDuration(v);
                        },
                      ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      context.t('sosAlarmLoudInSilent'),
                      style: TextStyle(color: Colors.grey.shade900),
                    ),
                    subtitle: Text(
                      context.t('sosAlarmLoudSubtitle'),
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    value: _alarmUseAlarmStream,
                    onChanged: _setAlarmMode,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 18),

          Center(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => _startHold(),
              onTapUp: (_) => _cancelHold(showHint: true),
              onTapCancel: () => _cancelHold(showHint: true),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF3A8DFF),
                          Color(0xFF7B4DFF),
                          Color(0xFFFF4DA6),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7B4DFF).withValues(alpha: 0.35),
                          blurRadius: 28,
                          spreadRadius: 6,
                        )
                      ],
                    ),
                  ),
                  Container(
                    width: 150,
                    height: 150,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.transparent,
                    ),
                    child: Center(
                      child: _sending
                          ? const CircularProgressIndicator(
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            )
                          : _holding
                              ? Text(
                                  '$_holdSecondsLeft',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 64,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.warning_amber_rounded,
                                        color: Colors.white, size: 44),
                                    const SizedBox(height: 8),
                                    Text(
                                      context.t('sosTitle'),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 34,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            context.t('sosHoldFooterHint'),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
          ),
        ],
      ),
    );
  }
}
