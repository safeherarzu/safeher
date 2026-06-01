import 'package:flutter/material.dart';

class AppStrings {
  static const Map<String, Map<String, String>> _localized = {
    'tr': {
      'map': 'Harita',
      'profile': 'Profil',
      'settings': 'Ayarlar',
      'account': 'Hesabım',
      'securitySettings': 'Güvenlik Ayarları',
      'aboutApp': 'Uygulama Hakkında',
      'aboutVersionTitle': 'Sürüm',
      'settingsSubtitle': 'Hesabım, güvenlik ve uygulama bilgileri',
      'login': 'Giriş Yap',
      'register': 'Kayıt Ol',
      'forgotPassword': 'Şifremi Unuttum',
      'email': 'E-posta',
      'password': 'Şifre',
      'passwordAgain': 'Şifre (Tekrar)',
      'rememberMe': 'Beni Hatırla',
      'sendResetLink': 'Bağlantı Gönder',
      'noAccountRegister': 'Hesabın yok mu? Kayıt ol',
      'haveAccountLogin': 'Zaten hesabın var mı? Giriş yap',
      'forgotPasswordShort': 'Şifremi unuttum',
      'backToLogin': 'Girişe dön',
      'resetMailSent': 'Şifre yenileme e-postası gönderildi.',
      'loginFailed': 'Giriş başarısız.',
      'registerFailed': 'Kayıt başarısız.',
      'processFailed': 'İşlem başarısız.',
      'passwordMismatch': 'Şifreler eşleşmiyor.',
      'skip': 'Atla',
      'onboarding1Title': 'Her adımda güvende.',
      'onboarding1Subtitle':
          'SafeHer, bulunduğun bölgede güvenli noktaları keşfetmeni ve acil durumda hızlıca yardım istemeni sağlar.',
      'swipeToContinue': 'Devam etmek için sola kaydır',
      'enterApp': 'Uygulamaya Gir',
      'aboutText':
          'SafeHer, kullanıcıların güvenli ve güvensiz bölgeleri anonim olarak işaretlemesine ve acil durumlarda hızlı SOS akışıyla konum paylaşmasına yardımcı olur.',
      'releaseBeta': 'Dağıtım: App Store ve Google Play üzerinden.',
      'updateAvailableTitle': 'Güncelleme var',
      'updateAvailableBody':
          'SafeHer\'ın yeni sürümü ({version}) yayında. En iyi deneyim için App Store veya Google Play\'den güncelleyin.',
      'updateNow': 'Güncelle',
      'updateLater': 'Sonra',
      'updateBannerTitle': 'Yeni sürüm mevcut',
      'updateBannerSubtitle':
          'SafeHer {version} yayında. Güncellemek için dokunun.',
      'aboutPrivacy': 'Gizlilik ve KVKK metinlerini Hesabım ve başlangıç onay ekranında inceleyebilirsin.',
      'language': 'Dil',
      'languageSystem': 'Sistem dili',
      'languageTurkish': 'Türkçe',
      'languageEnglish': 'English',
      'securityPrivacyTitle': 'Gizlilik ve Güvenlik',
      'locationReminders': 'Konum izni hatırlatmaları',
      'locationRemindersSubtitle': 'Konum kapalıysa uygulama içinde uyarı gösterilir.',
      'quickSosConfirm': 'Hızlı SOS onayı',
      'quickSosConfirmSubtitle': 'Yanlış tetiklemeleri azaltmak için önerilir.',
      'note': 'Not',
      'sosSettingsHint': 'SOS alarm süresi ve sessiz mod ayarı SOS ekranından yönetilir.',
      'sosTitle': 'SOS',
      'sosScreenSubtitle':
          'Acil kişilerinize konumunuza ek olarak WhatsApp’tan mesaj gönderir.',
      'sosEmergencyContacts': 'Acil Kişiler',
      'sosPhoneHint': 'Telefon (örn: 905xxxxxxxxx)',
      'sosAddContact': 'Kişi Ekle',
      'sosFromContacts': 'Rehberden',
      'sosNoContactsYet': 'Henüz acil kişi yok.',
      'sosAlarmSettings': 'SOS Alarm Ayarları',
      'sosDuration': 'Süre:',
      'sosSeconds': '{n} sn',
      'sosAlarmLoudInSilent': 'Sessiz modda da yüksek sesle çal',
      'sosAlarmLoudSubtitle': 'Açıkken alarm akışı kullanılır (daha caydırıcı).',
      'sosHoldFooterHint':
          '2 saniye basılı tutarak SOS gönderirsin. Alarm yalnızca bu ekrandayken çalar.',
      'sosContactAdded': 'Acil kişi eklendi',
      'sosContactsPermissionNeeded':
          'Rehber izni gerekli. Ayarlardan SafeHer için rehber erişimini açabilirsin.',
      'sosContactNoPhone': 'Seçilen kişide telefon numarası yok.',
      'sosNumberUnreadable': 'Numara okunamadı.',
      'sosAddedFromContacts': 'Rehberden eklendi: {phone}',
      'sosContactBookError': 'Rehber hatası: {error}',
      'sosAddContactsFirst': 'Önce acil kişileri ekleyin.',
      'sosLocationDenied': 'Konum izni verilmedi.',
      'sosWhatsAppSent': 'WhatsApp’a konum gönderildi.',
      'sosSendError': 'SOS gönderme hatası: {error}',
      'sosHoldTwoSeconds': 'Lütfen 2 saniye basılı tutun.',
      'sosWhatsAppBody':
          '🚨 SOS! Acil durum.\nKonumum: {url}\nYardımınıza ihtiyacım var.',
      'sosEmptyContactsProfileHint':
          'Acil kişi eklenmemiş. SOS ekranından ekleyebilirsin.',
      'sosContactRemovedSnack': 'Acil kişi silindi.',
      'routePlanButton': 'Rota & uyarı',
      'routePlanSheetTitle': 'Gideceğin adres',
      'routePlanSheetBody':
          'Bulunduğun konum (veya haritayı ortaladığın nokta) ile hedef arasında düz hat üzerinde güvensiz işaretleri tararız. Gerçek sürüş yolundan farklı olabilir; yine de dikkat çekmek için uygundur.',
      'routePlanDestinationHint': 'Hedef adres (örn. Kadıköy İskelesi)',
      'routePlanSuggestionsLoading': 'Adresler aranıyor…',
      'routePlanSuggestionsEmpty': 'Öneri bulunamadı. Yazmaya devam edin veya farklı bir ifade deneyin.',
      'routePlanAnalyze': 'Güvensiz bölgeleri kontrol et',
      'routePlanClose': 'Kapat',
      'routePlanClearRoute': 'Rotayı haritadan kaldır',
      'routePlanOriginMissing':
          'Başlangıç noktası yok. Konum iznini açın veya haritayı bulunduğun yere kaydırın.',
      'routePlanGeocodeFail': 'Hedef adres bulunamadı.',
      'routePlanUnsafeTitle': 'Rota hattına yakın güvensiz işaretler',
      'routePlanUnsafeLine': '≈ {meters} m — etiketler: {tags}',
      'routePlanUnsafeNone':
          'Bu hat çevresinde (yaklaşık 220 m) güvensiz işaret görünmüyor. Yine de çevreye dikkat et.',
      'routeNotifyTitle': 'SafeHer rota',
      'routeNotifyBodyMany':
          'Dikkat: rota hattına yakın {count} güvensiz bölge işaretlendi.',
      'routeNotifyBodyZero':
          'Rota hattına yakın güvensiz işaret bulunamadı. İyi yolculuklar.',
      'profileStatPinTotal': 'Toplam Pin',
      'profileStatPinSafe': 'Güvenli',
      'profileStatPinUnsafe': 'Güvensiz',
      'mapFilterActiveSafe': 'Gösterim: yalnız güvenli pinler',
      'mapFilterActiveUnsafe': 'Gösterim: yalnız güvensiz pinler',
      'mapFilterClear': 'Filtreyi kaldır',
      'mapFilterEmpty': 'Bu görünümde gösterilecek pin yok.',
      'mapPinTagsEmpty': 'Etiket yok',
      'deletePinButton': 'İşaretimi sil',
      'deletePinConfirmTitle': 'İşareti sil?',
      'deletePinConfirmBody':
          'Bu işaret haritadan kaldırılır. Bu işlem geri alınamaz.',
      'deletePinCancel': 'Vazgeç',
      'deletePinConfirm': 'Sil',
      'deletePinSuccess': 'İşaret silindi.',
      'deletePinFailed': 'Silinemedi: {error}',
      'deletePinOnlyOwner': 'Bu işareti yalnızca ekleyen kullanıcı silebilir.',
    },
    'en': {
      'map': 'Map',
      'profile': 'Profile',
      'settings': 'Settings',
      'account': 'My Account',
      'securitySettings': 'Security Settings',
      'aboutApp': 'About App',
      'aboutVersionTitle': 'Version',
      'settingsSubtitle': 'Account, security and app details',
      'login': 'Sign In',
      'register': 'Create Account',
      'forgotPassword': 'Forgot Password',
      'email': 'Email',
      'password': 'Password',
      'passwordAgain': 'Password (Again)',
      'rememberMe': 'Remember Me',
      'sendResetLink': 'Send Link',
      'noAccountRegister': "Don't have an account? Sign up",
      'haveAccountLogin': 'Already have an account? Sign in',
      'forgotPasswordShort': 'Forgot password',
      'backToLogin': 'Back to sign in',
      'resetMailSent': 'Password reset email sent.',
      'loginFailed': 'Login failed.',
      'registerFailed': 'Registration failed.',
      'processFailed': 'Operation failed.',
      'passwordMismatch': 'Passwords do not match.',
      'skip': 'Skip',
      'onboarding1Title': 'Stay safer every step.',
      'onboarding1Subtitle':
          'SafeHer helps you discover safer spots around you and reach out fast in an emergency.',
      'swipeToContinue': 'Swipe left to continue',
      'enterApp': 'Enter App',
      'aboutText':
          'SafeHer helps users mark safe and unsafe areas anonymously and share location quickly via SOS in emergencies.',
      'releaseBeta': 'Available on the App Store and Google Play.',
      'updateAvailableTitle': 'Update available',
      'updateAvailableBody':
          'A new version of SafeHer ({version}) is available. Please update from the App Store or Google Play.',
      'updateNow': 'Update',
      'updateLater': 'Later',
      'updateBannerTitle': 'Update available',
      'updateBannerSubtitle':
          'SafeHer {version} is available. Tap to update.',
      'aboutPrivacy': 'You can review privacy and KVKK texts from Account and startup consent screens.',
      'language': 'Language',
      'languageSystem': 'System language',
      'languageTurkish': 'Turkish',
      'languageEnglish': 'English',
      'securityPrivacyTitle': 'Privacy & Security',
      'locationReminders': 'Location permission reminders',
      'locationRemindersSubtitle': 'Shows in-app warning when location is off.',
      'quickSosConfirm': 'Quick SOS confirmation',
      'quickSosConfirmSubtitle': 'Recommended to reduce accidental triggers.',
      'note': 'Note',
      'sosSettingsHint': 'SOS alarm duration and silent mode are managed on SOS screen.',
      'sosTitle': 'SOS',
      'sosScreenSubtitle':
          'Sends your location to trusted contacts via WhatsApp in an emergency.',
      'sosEmergencyContacts': 'Emergency contacts',
      'sosPhoneHint': 'Phone (e.g. 905xxxxxxxxx)',
      'sosAddContact': 'Add contact',
      'sosFromContacts': 'From contacts',
      'sosNoContactsYet': 'No emergency contacts yet.',
      'sosAlarmSettings': 'SOS alarm settings',
      'sosDuration': 'Duration:',
      'sosSeconds': '{n} s',
      'sosAlarmLoudInSilent': 'Play loudly even in silent mode',
      'sosAlarmLoudSubtitle': 'When on, uses the alarm stream (more attention-grabbing).',
      'sosHoldFooterHint':
          'Hold for 2 seconds to send SOS. The alarm only plays while you are on this screen.',
      'sosContactAdded': 'Emergency contact added',
      'sosContactsPermissionNeeded':
          'Contacts permission is required. You can enable it for SafeHer in Settings.',
      'sosContactNoPhone': 'The selected contact has no phone number.',
      'sosNumberUnreadable': 'Could not read the number.',
      'sosAddedFromContacts': 'Added from contacts: {phone}',
      'sosContactBookError': 'Contacts error: {error}',
      'sosAddContactsFirst': 'Add emergency contacts first.',
      'sosLocationDenied': 'Location permission was not granted.',
      'sosWhatsAppSent': 'Location sent via WhatsApp.',
      'sosSendError': 'Could not send SOS: {error}',
      'sosHoldTwoSeconds': 'Please hold for 2 seconds.',
      'sosWhatsAppBody':
          '🚨 SOS! Emergency.\nMy location: {url}\nI need help.',
      'sosEmptyContactsProfileHint':
          'No emergency contacts yet. Add them from the SOS screen.',
      'sosContactRemovedSnack': 'Emergency contact removed.',
      'routePlanButton': 'Route & alerts',
      'routePlanSheetTitle': 'Where you’re going',
      'routePlanSheetBody':
          'We scan unsafe community pins along a straight line from your location (or the map center) to the destination. This is not turn-by-turn navigation, but it highlights areas to watch.',
      'routePlanDestinationHint': 'Destination (e.g. city landmark)',
      'routePlanSuggestionsLoading': 'Searching addresses…',
      'routePlanSuggestionsEmpty': 'No suggestions. Keep typing or try another phrase.',
      'routePlanAnalyze': 'Check unsafe areas',
      'routePlanClose': 'Close',
      'routePlanClearRoute': 'Remove route from map',
      'routePlanOriginMissing':
          'No start point. Enable location or move the map to where you are.',
      'routePlanGeocodeFail': 'Destination address could not be found.',
      'routePlanUnsafeTitle': 'Unsafe pins near your route line',
      'routePlanUnsafeLine': '≈ {meters} m — tags: {tags}',
      'routePlanUnsafeNone':
          'No unsafe pins within about 220 m of this line. Stay aware of your surroundings.',
      'routeNotifyTitle': 'SafeHer route',
      'routeNotifyBodyMany':
          'Heads up: {count} unsafe area pin(s) are near your route line.',
      'routeNotifyBodyZero':
          'No unsafe pins near the route line. Have a safe trip.',
      'profileStatPinTotal': 'Total pins',
      'profileStatPinSafe': 'Safe',
      'profileStatPinUnsafe': 'Unsafe',
      'mapFilterActiveSafe': 'Showing: safe pins only',
      'mapFilterActiveUnsafe': 'Showing: unsafe pins only',
      'mapFilterClear': 'Clear filter',
      'mapFilterEmpty': 'No pins to show in this view.',
      'mapPinTagsEmpty': 'No tags',
      'deletePinButton': 'Delete my pin',
      'deletePinConfirmTitle': 'Delete this pin?',
      'deletePinConfirmBody':
          'This pin will be removed from the map. This cannot be undone.',
      'deletePinCancel': 'Cancel',
      'deletePinConfirm': 'Delete',
      'deletePinSuccess': 'Pin deleted.',
      'deletePinFailed': 'Could not delete: {error}',
      'deletePinOnlyOwner': 'Only the user who added this pin can delete it.',
    },
  };

  static String of(BuildContext context, String key) {
    final code = Localizations.localeOf(context).languageCode;
    final lang = _localized.containsKey(code) ? code : 'tr';
    return _localized[lang]?[key] ?? _localized['tr']?[key] ?? key;
  }
}

extension AppStringsX on BuildContext {
  String t(String key) => AppStrings.of(this, key);

  /// `{key}` placeholders in the string are replaced with [values].
  String tReplace(String key, Map<String, String> values) {
    var s = AppStrings.of(this, key);
    values.forEach((k, v) => s = s.replaceAll('{$k}', v));
    return s;
  }
}
