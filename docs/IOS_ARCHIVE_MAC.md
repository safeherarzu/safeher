# iOS Archive — Mac (eş) — 1.0.3 build 10

**Önemli:** Proje kökü `safeher` (içinde `lib/` ve `ios/` yan yana). `mobile/ios` veya `SafeHer-Cursor` klasörünü Xcode’da açmayın.

## Komutlar (Terminal)

```bash
cd ~/Documents/safeher
git pull origin main
rm -f ios/Flutter/Generated.xcconfig
flutter pub get
cd ios && pod install && cd ..
```

`flutter pub get` sonrası kontrol:

```bash
grep FLUTTER_BUILD ios/Flutter/Generated.xcconfig
```

Beklenen:

```
FLUTTER_BUILD_NAME=1.0.3
FLUTTER_BUILD_NUMBER=10
```

## Xcode

```bash
open ios/Runner.xcworkspace
```

1. **Product → Clean Build Folder** (⇧⌘K)
2. **Runner** → **General** → Version **1.0.3**, Build **10** (elle değiştirmeyin; yukarıdaki grep yanlışsa önce `flutter pub get` tekrar)
3. Üstte **Any iOS Device (arm64)**
4. **Product → Archive**
5. Organizer’da sürüm **1.0.3 (10)** görünmeli → **Distribute App** → App Store Connect

## Hâlâ 1.0.3 (9) görünüyorsa

- Yanlış klasör / eski `Generated.xcconfig` → yukarıdaki `rm` + `flutter pub get`
- Xcode’u kapatıp aç, Clean Build Folder
- App Store Connect’te yeni build **10** olmalı (9 kapalıysa 10 şart)
