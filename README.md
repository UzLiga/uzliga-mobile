# Playzon Mobile (Flutter)

O‘yinchi ilovasi — Playzon API: `https://playzon.asilbek.tech/api/v1`

> **Stadion egasi ERP/CRM** bu repoda emas. Hamkasb (`xojiakbardev`) alohida ERP yozadi va backend Owner API ga ulaydi:  
> [`uzliga-backend/docs/OWNER_ERP_INTEGRATION.md`](https://github.com/UzLiga/uzliga-backend/blob/main/docs/OWNER_ERP_INTEGRATION.md) · Swagger: https://playzon.asilbek.tech/api/v1/docs

## Run

```bash
flutter pub get
flutter run
```

API base: `lib/core/constants.dart` → `apiBase`.

## Build

```bash
# Universal APK — barcha Android telefonlar (bitta fayl)
flutter build apk --release

# Yoki ABI bo‘yicha kichikroq fayllar
flutter build apk --release --split-per-abi
flutter build appbundle --release
```

Yuklab olish (prod): https://playzon.asilbek.tech/download  
To‘g‘ridan APK: https://playzon.asilbek.tech/Playzon.apk

## Org

- Backend: https://github.com/UzLiga/uzliga-backend  
- Frontend: https://github.com/UzLiga/uzliga-frontend  
- Bot: https://github.com/UzLiga/uzliga-bot  
