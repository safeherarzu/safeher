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
      'forgotPasswordShort': 'Şifremi unuttum',
      'backToLogin': 'Girişe dön',
      'resetMailSent': 'Şifre yenileme e-postası gönderildi.',
      'loginFailed': 'Giriş başarısız.',
      'registerFailed': 'Kayıt başarısız.',
      'processFailed': 'İşlem başarısız.',
      'passwordMismatch': 'Şifreler eşleşmiyor.',
      'skip': 'Atla',
      'swipeToContinue': 'Devam etmek için sola kaydır',
      'enterApp': 'Uygulamaya Gir',
      'aboutText':
          'SafeHer, kullanıcıların güvenli ve güvensiz bölgeleri anonim olarak işaretlemesine ve acil durumlarda hızlı SOS akışıyla konum paylaşmasına yardımcı olur.',
      'releaseBeta': 'Dağıtım: Kapalı test (beta)',
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
    },
    'en': {
      'map': 'Map',
      'profile': 'Profile',
      'settings': 'Settings',
      'account': 'My Account',
      'securitySettings': 'Security Settings',
      'aboutApp': 'About App',
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
      'forgotPasswordShort': 'Forgot password',
      'backToLogin': 'Back to sign in',
      'resetMailSent': 'Password reset email sent.',
      'loginFailed': 'Login failed.',
      'registerFailed': 'Registration failed.',
      'processFailed': 'Operation failed.',
      'passwordMismatch': 'Passwords do not match.',
      'skip': 'Skip',
      'swipeToContinue': 'Swipe left to continue',
      'enterApp': 'Enter App',
      'aboutText':
          'SafeHer helps users mark safe and unsafe areas anonymously and share location quickly via SOS in emergencies.',
      'releaseBeta': 'Release: Closed testing (beta)',
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
}
