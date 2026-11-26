# 🛡️ DepositGuard

**Never lose your rental security deposit to a dispute again.**
One Flutter + Dart codebase → **Web · Android · iOS · Windows**.

🌐 **Live web app:** https://gunjan0716.github.io/depositguard/ (deployed automatically by GitHub Actions)

## The problem

In Indian cities tenants routinely hand over deposits worth 2–10 months' rent.
At move-out, the refund turns into one person's word against another's:
"the wall was already like that", "that's normal wear", "you broke the sofa".
There is no shared, trusted record — so tenants lose money and landlords lose time.

## The solution

DepositGuard turns the move-in and move-out into **evidence both sides agreed on**,
and the deduction into **arithmetic, not argument**.

| Feature | What it does |
|---|---|
| 📋 Room-by-room checklist | Pre-filled checklist; add any item with its repair value |
| 📸 Hashed photo evidence | Every photo is stored with its SHA-256 hash and capture time; each thumbnail shows an integrity tick |
| ✍️ Dual e-signature | Tenant and landlord each draw a signature; when both sign, the move-in evidence is **sealed** |
| 🔒 Tamper-evident seal | The seal is a SHA-256 fingerprint of all move-in facts and photo hashes. Editing anything breaks it, and the app shows that |
| ✅ Verify a fingerprint | Paste the fingerprint the other party sent you to prove you're looking at the same evidence |
| ⚖️ Fair deduction engine | Normal wear & tear is never charged (1 condition level free per 12 months, configurable). Decline beyond that is charged pro-rata of the repair cost, with the reason shown for every item |
| 📄 Settlement PDF | Item-by-item report with deductions, refund, signatures and seal status, shared through the system share sheet / print dialog |
| 🧾 Rent ledger + HRA receipts | Mark rent paid (UPI, bank, cash, cheque), then generate one HRA rent receipt per month as a PDF |
| 👥 Tenant / landlord roles | Same app, two points of view; each party signs only as themselves |
| 🌙 Dark mode, 💾 offline storage, 📋 JSON backup | Data stays on the device; nothing is uploaded |

### Fair deduction rule (example)

17-month tenancy → 1 level of decline is free.

| Item | Move-in → Move-out | Charge |
|---|---|---|
| Walls & paint (₹18,000) | Good → Fair | ₹0 (wear & tear) |
| Sofa (₹22,000) | Fair → Damaged | 1/3 × ₹22,000 = ₹7,333 |
| Window glass (₹3,500) | Good → Damaged | 2/3 × ₹3,500 = ₹2,333 |

## Responsive by design

| Width | Layout |
|---|---|
| < 700 px (phones) | Bottom navigation bar |
| 700–1100 px (tablets, small windows) | Compact navigation rail |
| ≥ 1100 px (desktop web, maximised Windows) | Extended rail with labels |

## Run it

```bash
# 1. Generate the platform folders (lib/ and test/ are kept as they are)
flutter create --platforms=web,android,ios,windows --project-name depositguard --org app.depositguard .

# 2. Get packages and run the tests
flutter pub get
flutter test

# 3. Run
flutter run -d chrome     # Web
flutter run -d windows    # Windows desktop
flutter run -d <device>   # Android / iOS
```

Builds: `flutter build web`, `flutter build apk`, `flutter build windows`.

**iOS:** add `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription` to `ios/Runner/Info.plist`.

## CI / downloads

`.github/workflows/build.yml` runs on every push to `main`:

1. `flutter analyze` + `flutter test`
2. Builds **web** and deploys it to **GitHub Pages**
3. Builds the **Android APK** and **Windows zip** and attaches them to a **GitHub Release**

## Project structure

```
lib/
  main.dart                 app, theme, responsive shell
  models.dart               data model, deduction engine, seal fingerprint
  state.dart                app state + local persistence
  services/report.dart      settlement PDF and HRA receipts
  widgets/                  shared UI, signature pad
  screens/                  onboarding, overview, inspection, move-out, rent, seal, settings
test/                       unit tests (engine, seal, JSON) + widget test
```

## Roadmap

- Cloud sync so both parties see the same tenancy live
- Aadhaar eSign / DigiLocker for legally stronger signatures
- Hindi and regional-language UI
- AI-assisted damage detection by comparing move-in vs move-out photos

## License

MIT
