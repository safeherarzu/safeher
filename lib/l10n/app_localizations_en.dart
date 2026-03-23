// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'SafeHer';

  @override
  String get safe => 'Safe';

  @override
  String get unsafe => 'Unsafe';

  @override
  String get sendSOS => 'Send SOS';

  @override
  String get cancel => 'Cancel';

  @override
  String get history => 'SOS History';

  @override
  String get stats => 'Statistics';

  @override
  String get safeRegions => 'Safe Regions';

  @override
  String get unsafeRegions => 'Unsafe Regions';

  @override
  String get myContributions => 'My Contributions';

  @override
  String get mySOS => 'My SOS';

  @override
  String get noSOS => 'No SOS records yet';
}
