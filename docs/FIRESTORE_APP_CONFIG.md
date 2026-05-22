# Güncelleme bildirimi — Firestore `app_config/store`

Uygulama açılışında sürüm kontrolü yapar. **Android için Firestore zorunludur** (Play Store API yok). iOS için Firestore yoksa iTunes mağaza sürümü kullanılır.

## Firebase Console

1. [Firebase Console](https://console.firebase.google.com) → projeniz → **Firestore Database**
2. Koleksiyon: `app_config` → belge ID: `store` (yoksa oluştur)
3. Alanlar (örnek — yeni sürüm yayınladığınızda güncelleyin):

| Alan | Örnek | Açıklama |
|------|--------|----------|
| `latest_version_android` | `1.0.3` | Play’deki sürüm adı |
| `latest_version_ios` | `1.0.3` | App Store sürüm adı |
| `min_version_android` | `1.0.2` | Bunun altındakilere uyarı |
| `min_version_ios` | `1.0.2` | Bunun altındakilere uyarı |
| `message_tr` | `Yeni sürüm: pin silme, rota önerileri ve daha fazlası.` | Diyalog metni |
| `message_en` | `New version: pin delete, route suggestions, and more.` | |
| `android_store_url` | `https://play.google.com/store/apps/details?id=com.safeher.womensafety` | |
| `ios_store_url` | App Store uygulama linkiniz | |
| `force_update` | `false` | `true` = kullanıcı “Sonra” diyemez |

4. **Firestore Rules** yayınlayın (`firebase deploy --only firestore:rules` veya Console → Rules → Publish).

## Test

- Telefonda eski sürüm (ör. 1.0.2) yüklü kalsın.
- `latest_version_*` = `1.0.3` yapın.
- Uygulamayı açın → “Güncelleme var” diyalogu görünmeli.
