// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => 'SafeHer';

  @override
  String get safe => 'Güvenli';

  @override
  String get unsafe => 'Güvensiz';

  @override
  String get sendSOS => 'SOS Gönder';

  @override
  String get cancel => 'İptal';

  @override
  String get history => 'SOS Geçmişi';

  @override
  String get stats => 'İstatistikler';

  @override
  String get safeRegions => 'Güvenli Bölgeler';

  @override
  String get unsafeRegions => 'Güvensiz Bölgeler';

  @override
  String get myContributions => 'Benim Katkılarım';

  @override
  String get mySOS => 'Gönderdiğim SOS';

  @override
  String get noSOS => 'Henüz SOS kaydı yok';
}
