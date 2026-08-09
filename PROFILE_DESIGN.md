# Playzon — Foydalanuvchi ilovasi: Profil dizayni (hozirgi holat)

Bu hujjat `uzliga-mobile` (o‘yinchi ilovasi) **Profil** bo‘limining dizayn holatini to‘liq tasvirlaydi: nima bor, qanday ishlaydi, FIFA karta qanday qurilgan, nimasi yetarli emas, va keyin nima qo‘shish mumkin.

**Asosiy fayl:** `lib/features/profile/profile_screen.dart`  
**Boshqa foydalanuvchi profili:** `lib/features/profile/user_profile_screen.dart`  
**FIFA kartasi widget:** `lib/shared/widgets/player_card.dart`  
**Tema:** `lib/core/theme/app_theme.dart` (Cyber Mint + Gold, Poppins)

---

## 1. Profil nima vazifa bajaradi?

Profil — oddiy “sozlamalar” sahifasi emas. Bu **shaxsiy hub**: o‘yinchi o‘zini ko‘radi, FIFA/karyera kartasini ochadi, tez yo‘llar orqali bron, hamyon, jamoa, battle va h.k. ga o‘tadi.

Bottom navigation (4-tab):

| Index | Tab | Route |
|------:|-----|-------|
| 0 | Asosiy | `/app` |
| 1 | O‘yinlar | `/app/games` |
| 2 | Lavhalar | `/app/reels` |
| 3 | **Profil** | `/app/profile` |

Til: **o‘zbekcha**. Scaffold foni transparent — ortida shell ambient/football backdrop ko‘rinadi.

---

## 2. Ekran tuzilmasi (yuqoridan pastga)

Pull-to-refresh `CustomScrollView`. Tartib:

```
┌─────────────────────────────────────┐
│ AppBar: «Profil»          [Tahrir]  │  ← pinned
├─────────────────────────────────────┤
│ 1. Hero header                      │  avatar + ism + OVR + reyting
│ 2. Premium · FIFA / Flip karta      │  locked upsell YOKI flip card
│ 3. Yutuqlar                         │  4 ta badge
│ 4. Referral (agar bor)              │  kod + copy
│ 5. Tezkor                           │  «Bora olaman» + 9 ta shortcut
│ 6. Menu card                        │  tahrir / tema / Telegram
│ 7. Mening reels                     │  3× grid thumbs
│ 8. Chiqish + versiya                │  Playzon 1.1.1+12
└─────────────────────────────────────┘
```

### 2.1 Hero header (`_HeroHeader`)

- Qorong‘u yashil gradient kartochka (radius ~18–22).
- Chapda **avatar** (72px, doira); verified bo‘lsa badge.
- O‘ngda:
  - To‘liq ism (w800)
  - Premium bo‘lsa oltin `workspace_premium` ikonkasi
  - Qator: `pozitsiya · telefon` (muted)
  - Chip: **OVR {overall}** (mint border)
  - ⭐ reyting (masalan `4.2`)

Bu blok FIFA kartasidan oldin “kimman?” signalini beradi.

### 2.2 Premium · FIFA bo‘limi (`_PremiumFifaSection`)

Ikki holat:

| Holat | UI |
|-------|-----|
| **Premium yo‘q** | Oltin borderli upsell: «Premium · FIFA karta», qisqa izoh, «Premium ochish» → `/app/premium` |
| **Premium bor** | `_FifaFlipCard` — old tomon FIFA, orqa tomon Karyera |

**Muhim biznes qoida:** FIFA flip tajribasi **faqat Premium** da. Free user faqat upsell ko‘radi.

### 2.3 Yutuqlar (`_Achievements`)

4 ta lokal badge (backend badges API yo‘q — client heuristika):

| Badge | Shart |
|-------|--------|
| Ilk o‘yin | `gamesPlayed >= 1` |
| Gol mashinasi | `goals >= 5` |
| Assistchi | `assists >= 5` |
| Premium | `isPremium == true` |

Ochilmaganlari xira, ochilganlari yorqinroq.

### 2.4 Referral (`_ReferralCard`)

Faqat `referralCode` bo‘lsa chiqadi. Kod + clipboard copy.

### 2.5 Tezkor

1. **«Bora olaman»** — `setAvailability` API (hardcode: 2 soat, 8 km, ready note). Status bekor/qayta sozlash UI yo‘q.
2. **`_QuickGrid`** — 4 ustunli 9 ta shortcut:

| Shortcut | Route |
|----------|-------|
| Bronlar | `/app/bookings` |
| Hamyon | `/app/wallet` |
| Xarita | `/app/map` |
| Turnir | `/app/tournaments` |
| Jamoa | `/app/teams` |
| Battle | `/app/battles` |
| O‘yinlar | `/app/games` |
| Reels | `/app/reels` |
| Xabar | `/app/notifications` |

### 2.6 Menu card

- Profilni tahrirlash (bottom sheet)
- Ko‘rinish (Dark/Light switch)
- Telegram bot (tashqi link)

Alohida **Settings** sahifasi yo‘q.

### 2.7 Mening reels

O‘z kliplari (max ~9 thumb, 3 ustun). Manage → `/app/my-reels`.

### 2.8 Chiqish

Logout + versiya yozuvi.

---

## 3. FIFA karta — to‘liq tushuntirish

### 3.1 Umumiy g‘oya

FIFA / Ultimate Team / DLS uslubidagi **o‘yinchi kartasi**: OVR, pozitsiya, avatar, 6 attribute. Profilida bu karta **flip** orqali karyera statistikaga aylanadi.

Asosiy chizilgan widget: `PlayerCard` (`lib/shared/widgets/player_card.dart`).  
Profil front: `_FifaFront` ichida `PlayerCard` + pastida `_MiniAttrs`.  
Profil back: `_CareerBack`.

### 3.2 Tier (rang) tizimi

`overall` ga qarab border/glow:

| OVR | Rang | Nom |
|----:|------|-----|
| ≥ 80 | `#E8B923` | Gold |
| ≥ 70 | `#3B82F6` | Blue |
| < 70 | `#94A3B8` | Silver |

### 3.3 Old tomon — FIFA (`_FifaFront`)

Vizual:

- To‘liq kenglikdagi gradient panel (tier rang + qorong‘u yashil/qora).
- Sarlavha: «FIFA karta» + «Aylantirish» (flip hint).
- Markazda `PlayerCard`:
  - O‘lcham ~118×162 (compact: 76×102)
  - Ism UPPERCASE
  - OVR katta raqam
  - Pozitsiya (GK / CB / CM / ST…)
  - Avatar (yoki placeholder)
  - Bayroq emoji 🇺🇿
  - Kichik PAC / SHO / PAS qatori kartada
  - Ixtiyoriy kapitan «C» badge (jamoa kontekstida)
- Pastida to‘liq 6 attr qatori (`_MiniAttrs`): **PAC, SHO, PAS, DRI, DEF, STA** (qiymatlar oltin)

Hint matn: «Surish yoki bosish — karyera».

Profilda `showFullStatsOnTap: false` — tap flipga tegishli; boshqa joylarda (public profile, pitch) tap stats bottom sheet ochadi.

### 3.4 Orqa tomon — Karyera (`_CareerBack`)

- Sarlavha «Karyera» + chip `Lv {careerLevel}`
- `careerTitle` (masalan «Mahalla afsonasi»)
- Chegirma matni: `Do‘konlarda X% chegirma` yoki shop hint
- Progress bar (`careerProgress`) + «Keyingi darajaga N o‘yin»
- Stats grid 1: O‘yin · Gol · Assist · Reyting
- Stats grid 2: Sariq · Qizil · OVR · Poz
- Ixtiyoriy: bo‘y / vazn / oyoq (chap/o‘ng/ikkalasi)

Hint: «Surish yoki bosish — FIFA karta».

### 3.5 Flip animatsiya (`_FifaFlipCard`)

- `AnimationController` ~**520ms**, `easeInOutCubic`
- Y-o‘qi bo‘yicha `rotateY` (perspective `0.0012`)
- Trigger: **tap** yoki **gorizontal swipe** (`primaryVelocity` abs ≥ 180)
- Haptic: `selectionClick`
- Orqa tomon mirror uchun qo‘shimcha `rotateY(π)`

### 3.6 Ma’lumot maydonlari (User)

Kartaga bog‘liq maydonlar:

- Identity: `firstName`, `fullName`, `avatarUrl`, `position`, `isPremium`, `isVerified`
- FIFA attrs: `pace`, `shooting`, `passing`, `dribbling`, `defending`, `stamina`
- Computed: `overall`
- Career: `careerLevel`, `careerTitle`, `careerProgress`, `careerGamesToNext`, `careerDiscountPercent`, `careerShopHint`
- Match stats: `gamesPlayed`, `goals`, `assists`, `yellowCards`, `redCards`, `rating`
- Physical: `heightCm`, `weightKg`, `preferredFoot`

**Default:** attr null bo‘lsa UI ko‘pincha **65** ko‘rsatadi.

### 3.7 Karyera darajalari (backend / local mirror)

`lib/shared/career.dart` dagi tierlar (UI hozir asosan API `User` maydonlaridan o‘qiydi; bu fayl kam ishlatiladi):

| O‘yinlar | Key | Title | Chegirma |
|--------:|-----|-------|--------:|
| 0 | rookie | Yangi o‘yinchi | 0% |
| 5 | mahalla | Mahalla afsonasi | 5% |
| 15 | semi | Yarim-professional | 10% |
| 30 | star | Yulduz | 15% |
| 50 | legend | Legenda | 20% |

### 3.8 Qayerda yana `PlayerCard` ishlatiladi?

- O‘z profil FIFA front
- Boshqa user public profile (hero card)
- Jamoa / pitch formation (`PitchFormation` shu faylda)
- Stats bottom sheet ichida compact preview

---

## 4. Profil tahrirlash (edit sheet)

AppBar edit yoki menu → modal bottom sheet:

- Avatar yuklash (`image_picker` + API)
- Ism
- Pozitsiya (GK … ST)
- Jins
- Oyoq
- Bo‘y / vazn
- Tug‘ilgan yil

**Eslatma (UI matnda):** FIFA attributlari odatda o‘yinlardan keladi — foydalanuvchi qo‘lda PAC/SHO kiritmaydi.

---

## 5. Profilga bog‘langan boshqa ekranlar

| Ekran | Holat | Izoh |
|-------|--------|------|
| **Bookings / Ticket** | Bor | Gold QR ticket (`booking_ticket.dart`) |
| **Wallet (To‘p vault)** | Bor, demo to‘lov | Vault animatsiya; «Click/Payme keyinroq» |
| **Premium paywall** | Bor, demo | `provider: 'fake'`, «OBUNA · DEMO» |
| **Battles** | Bor | Quick grid orqali |
| **My reels** | Bor | Grid + manage |
| **Notifications** | Bor | |
| **Public user profile** | Bor | Card + attribute bars + goals/assists/games + clips; premium flip yo‘q |
| **Free agents** | Appda bor | Profil quick gridda **yo‘q** |
| **Dedicated Settings** | Yo‘q | Faqat tema + Telegram + logout |

---

## 6. Vizual til (dizayn tizimi)

### Ranglar

| Token | Hex | Vazifa |
|-------|-----|--------|
| Primary (Cyber Mint) | `#00CC7A` | CTA, OVR chip, accent |
| Gold | `#E8B923` | Premium, FIFA tier, career |
| BG | `#041510` | Dark background |
| Surface | `#0B221A` → `#103028` | Kartalar |
| Ink / Muted | `#F2FFF8` / `#8FB8A6` | Matn |

Light mode ham bor (`lightBg` `#F2FBF7`…), profil shell transparent.

### Tipografiya

Google Fonts **Poppins**. FIFA/career da og‘ir vaznlar: w800–w900.

### Shakl / effekt

- Radius: 14–24
- Soft gold/green glow, gradient fill
- Material outlined icons (maxsus FIFA PNG asset yo‘q — hammasi Flutter draw)
- Avatar/reels: network image (`CachedNetworkImage` / `PcNetworkImage`)

### Animatsiyalar (profil zonasida)

1. FIFA Y-flip + haptic  
2. Wallet vault / coin (wallet ekranida)  
3. Shell football tab transition (nav)

---

## 7. Hozirgi holat — qisqa verdict

**Nima yaxshi tayyor:**

- Profil hub sifatida boy va aniq ierarxiya
- Premium-gated FIFA + karyera flip — kuchli differentsiator
- Shared `PlayerCard` bir necha joyda qayta ishlatiladi
- Tezkor grid + bron ticket + reels bog‘langan
- Dark/light + edit sheet ishlaydi

**Nima zaif / yarim tayyor:**

- To‘lovlar demo (wallet + premium fake)
- Yutuqlar faqat lokal 4 ta qoida
- `myTeamsProvider` invalidate qilinadi, lekin profil UI da **ko‘rsatilmaydi**
- `User.topBalance` modelda bor — profil hero da **ko‘rinmaydi**
- «Bora olaman» hardcode payload; status boshqaruvi yo‘q
- Alohida sozlamalar / maxfiylik / til / qurilma token UI yo‘q
- Public profile kliplariga tap global reels ga ketadi (shu user feed emas)
- Attr yo‘q bo‘lsa default 65 — “haqiqiy” emasdek tuyulishi mumkin
- `career.dart` helper UI da deyarli ishlatilmaydi

---

## 8. Nima qo‘shish / yaxshilash mumkin (takliflar)

### A. FIFA / karyera tajribasi

1. **Season / form streak** — oxirgi 5 o‘yin formasi (W/D/L yoki rating dots) kartaning orqa/oldiga.
2. **Compare card** — do‘st bilan yonma-yon OVR solishtirish.
3. **Share FIFA card** — PNG/story export (Instagram/Telegram).
4. **Card skins** — Premium skinlar (gold foil, club kit border, city badge).
5. **Attr trend** — PAC/SHO oshishi/pasayishi oxirgi oylik sparkline.
6. **Empty state** — yangi user uchun «Birinchi o‘yinni o‘yna — OVR ochiladi» (65 default o‘rniga).
7. **Public profile da ham flip** — premium userlar uchun karyera orqa tomoni boshqalarga ko‘rinsin (privacy toggle bilan).

### B. Profil hub

8. **Hamyon balansi chip** — hero yonida `topBalance` / To‘p.
9. **Mening jamoalarim** — `myTeamsProvider` ni haqiqatan render qilish.
10. **Active booking ticket preview** — keyingi bronning mini ticket’i profil tepasida.
11. **Availability panel** — radius/soat tanlash, «Band» / «Tayyor» status, auto-expire countdown.
12. **Free agents** shortcut — tezkor gridga qo‘shish.
13. **Settings sahifasi** — til, push, maxfiylik, qurilmalar, hisobni o‘chirish.
14. **Referral UX** — invite link + «necha do‘st keldi» counter.

### C. Yutuqlar / ijtimoiy

15. **Backend badges** — ko‘proq yutuq, progress %, rarity.
16. **Follow / challenge** — public profilga «Battle chaqir» CTA.
17. **Clips deep-link** — boshqa user reelsini shu user feedida ochish.

### D. To‘lov / Premium

18. Real **Click / Payme** integratsiyasi (demo yorliqlarini olib tashlash).
19. Premium benefit checklist FIFA upsell ichida (hozir matn qisqa).
20. Premium muddat tugash countdown profil hero da.

### E. Dizayn polish

21. FIFA kartaga engil **parallax / shine** (motion 1 ta, shovqinsiz).
22. Light mode da FIFA gradientlarni qayta kalibrlash (hozir darkga optimallashtirilgan).
23. Hero + FIFA oralig‘ida bitta composition — ikkala blok bir xil “card language”da birlashishi.
24. Accessibility: OVR/attr kontrast, font scaling.

---

## 9. Fayl xaritasi (tez topish)

```
uzliga-mobile/
├── lib/features/profile/
│   ├── profile_screen.dart          ← asosiy profil hub + bookings screen
│   └── user_profile_screen.dart     ← boshqa user
├── lib/shared/widgets/
│   ├── player_card.dart             ← FIFA PlayerCard + PitchFormation
│   └── booking_ticket.dart          ← gold QR ticket
├── lib/shared/career.dart           ← karyera tier helper (kam ishlatiladi)
├── lib/features/wallet/             ← To‘p vault
├── lib/features/premium/            ← paywall
├── lib/features/battles/
├── lib/features/reels/my_reels_screen.dart
└── lib/core/theme/app_theme.dart
```

API base (prod): `https://playzon.asilbek.tech/api/v1`

---

## 10. Xulosa

Profil hozir **kuchli vizual hub**: hero → **Premium FIFA flip (karta ↔ karyera)** → yutuqlar → tezkor harakatlar → engil sozlamalar → reels. FIFA qismi eng yorqin differentsiator, lekin u **to‘lov/premium demo** va **ba’zi bog‘lanmagan providerlar** (jamoalar, balans) bilan hali to‘liq “product polish” darajasida emas.

Keyingi eng katta dizayn+mahsulot qadamlari: real to‘lov, jamoalar/balans/ticket preview ni hubga chiqarish, yutuqlarni backendga ko‘chirish, FIFA share/skin, availability ni to‘liq panel qilish.
