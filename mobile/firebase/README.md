# Firebase Rules Deploy

Bu klasördeki `firestore.rules` dosyasını Firebase'e deploy etmek için:

```bash
firebase login
firebase use safeher-66333
firebase deploy --only firestore:rules
```

Not:
- Deploy öncesi kuralları emulator veya staging projede test edin.
- Production'da `allow read, write: if true` gibi açık kurallar kullanmayın.
- Rules guncellendi: `locations` koleksiyonunda create/update/delete yetkileri daraltildi (author + oy artisi mantigi).

