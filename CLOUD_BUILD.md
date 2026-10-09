# Cloud APK Builds — Cyborg Studio POS

The app is built in the cloud because the development VM cannot run Gradle
(its network sandbox resets the Java build tool's own connections). The code
itself is complete and verified locally (`flutter analyze` clean, all tests
passing); only the final APK packaging step needs a normal build machine.

Two routes are prepared. **GitHub Actions is ready to use** — the workflow
file `.github/workflows/build-apk.yml` is already in this repo. Codemagic is
the alternative if GitHub does not suit.

---

## Route 1 — GitHub Actions (prepared)

### What you (the owner) need to do — one time

1. Create a free account at <https://github.com> (if you don't have one).
2. Create a **new PRIVATE repository** (e.g. `all-in-one-pos`). Keep it
   private: the app is a commercial product.
3. Push this project to that repo:

   ```bash
   cd pos_app
   git remote add origin https://github.com/<your-username>/all-in-one-pos.git
   git push -u origin main
   ```

   (GitHub will ask you to sign in — a personal access token or the GitHub
   desktop/CLI login both work.)

### Every time you want an APK

- The workflow runs automatically on every push to `main`, or manually:
  repo page → **Actions** tab → **Build APK** → **Run workflow**.
- It runs `flutter pub get` → `flutter analyze` → `flutter test` →
  `flutter build apk --debug`. If analyze or a test fails, the run stops
  and no APK is produced — fix the code first.
- When the run is green: open the run → **Artifacts** section at the bottom
  → download **`all-in-one-pos-debug-apk`** → unzip → `app-debug.apk`.
- Install on the phone/tablet: copy the APK over and open it (Android will
  ask to allow "install from this source" once). This is a **debug** APK —
  fine for testing and the pilot; a signed release build comes later, before
  selling.

Notes:

- The vendored packages `vendor/sqlite3` and `vendor/sqlite3_flutter_libs`
  are committed inside the repo with relative paths in `pubspec.yaml`, so
  the cloud runner resolves everything with no extra setup.
- Free GitHub accounts include Actions minutes for private repos; one build
  takes only a few minutes.

## Route 2 — Codemagic (alternative)

Codemagic (<https://codemagic.io>) is a build service made for Flutter.

1. Sign up (you can sign in with your GitHub account) and connect the same
   GitHub repo.
2. Either use Codemagic's visual workflow editor (Flutter workflow →
   build Android → APK), or commit a `codemagic.yaml` at the repo root:

   ```yaml
   workflows:
     android-debug:
       name: Android debug APK
       environment:
         flutter: stable
         java: 17
       scripts:
         - flutter pub get
         - flutter analyze
         - flutter test
         - flutter build apk --debug
       artifacts:
         - build/app/outputs/flutter-apk/*.apk
   ```

3. Start the build from the Codemagic dashboard and download the APK from
   the build's Artifacts. Codemagic's free tier includes a monthly build
   allowance.

Pick **one** route — using both is harmless but unnecessary.

## မြန်မာ အကျဉ်းချုပ်

- APK ကို cloud မှာ ဆောက်ပါမယ် — ဒီ development computer က Gradle build
  မ run နိုင်လို့ပါ။ App code ကတော့ ပြီးပြည့်စုံ စစ်ဆေးပြီးသားပါ။
- **လုပ်ရမှာတွေက** — (၁) GitHub အကောင့် ဖွင့်ပါ၊ (၂) **PRIVATE repo**
  အသစ် တစ်ခု ဆောက်ပါ၊ (၃) ဒီ project ကို အဲဒီ repo ထဲ push လုပ်ပါ။
- Push လုပ်ပြီးတာနဲ့ GitHub **Actions** tab မှာ build အလိုအလျောက်
  လည်ပါမယ်။ Build အောင်ရင် အဲဒီ run ရဲ့ **Artifacts** ထဲက
  **all-in-one-pos-debug-apk** ကို download ဆွဲပြီး ဖုန်း/tablet မှာ
  install လုပ်ရုံပါပဲ။
- Codemagic ဆိုတဲ့ နောက်ထပ် ဝန်ဆောင်မှုနဲ့လည်း အလားတူ ဆောက်လို့
  ရပါတယ် — နှစ်ခုထဲက တစ်ခု ရွေးရင် လုံလောက်ပါတယ်။
- ဒါက စမ်းသပ်ဖို့ **debug APK** ပါ — တကယ် ရောင်းချခါနီးကျမှ signed
  release build ထုတ်ပါမယ်။
