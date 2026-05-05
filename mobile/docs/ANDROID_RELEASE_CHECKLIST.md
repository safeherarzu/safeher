# Android Release Checklist (SafeHer)

## 1) Product freeze
- [ ] Marker ekleme, etiket, arama, SOS akışları gerçek cihazda test edildi
- [ ] Acil kişi ekleme/silme + WhatsApp yönlendirme doğrulandı
- [ ] Login/Register/Logout akışı doğrulandı

## 2) Firebase hardening
- [ ] `mobile/firebase/firestore.rules` deploy edildi
- [ ] Firestore indexes gereksinimleri kontrol edildi
- [ ] Firebase project: `safeher-66333` production olarak doğrulandı
- [ ] Crashlytics/Analytics etkinleştirildi (opsiyonel ama önerilir)

## 3) Android signing
- [ ] Keystore oluşturuldu (`key.jks`)
- [ ] `android/key.properties` eklendi (repo dışında tutulmalı)
- [ ] `build.gradle.kts` release signing config bağlandı

## 4) Versioning
- [ ] `pubspec.yaml` version artırıldı (ör. `1.0.1+2`)
- [ ] Release notes hazırlandı

## 5) Play Console prep
- [ ] App icon + feature graphic + screenshots yüklendi
- [ ] Privacy Policy URL eklendi
- [ ] Data Safety formu dolduruldu
- [ ] Content rating tamamlandı
- [ ] KVKK/ToS linkleri uygulama içinde erişilebilir

## 6) Build and upload
- [ ] `flutter clean && flutter pub get`
- [ ] `flutter build appbundle --release`
- [ ] `build/app/outputs/bundle/release/app-release.aab` Play Console'a yüklendi

## 7) Post-release watch
- [ ] İlk 24 saat crash/freezes takip edildi
- [ ] Marker create success rate ve SOS flow ölçüldü
- [ ] Kullanıcı geri bildirimlerinden hotfix listesi çıkarıldı

