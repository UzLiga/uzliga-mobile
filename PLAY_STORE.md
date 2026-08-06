# Playzon — Google Play ga chiqarish

Ogohlantirish (Play Protect) **to‘liq** ketishi uchun ilova Play Store’da bo‘lishi kerak.

## Tayyor narsalar
- Release keystore: `uzliga-mobile/android/app/playzon-release.jks`
- Backup: `Playzon-keystore-BACKUP.txt` (saqlang!)
- Maxfiylik: https://playzon.asilbek.tech/privacy
- AAB: `build/app/outputs/bundle/release/app-release.aab`
- Package: `tech.asilbek.playzon`

## Qadamlar (sizning Google akkauntingiz bilan)
1. https://play.google.com/console — developer akkaunt ($25 bir martalik)
2. Create app → **Playzon**
3. Store listing:
   - Short/full description
   - Icon 512×512, feature graphic 1024×500
   - Screenshots (telefon)
4. Privacy policy URL: `https://playzon.asilbek.tech/privacy`
5. App content / Data safety anketasini to‘ldiring
6. Production (yoki Internal testing) → Upload `app-release.aab`
7. Reviewga yuboring (1–7 kun)

## Build
```bash
cd uzliga-mobile
flutter build appbundle --release
```

Internal testing orqali 12 ta testerga berib, tezroq tekshirish mumkin.
