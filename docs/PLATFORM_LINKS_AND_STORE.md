# Links, signed-out browsing and the store fixes (batch D, 2026-10-19)

What changed on the platform side for the parity work (docs/APP_PARITY_AUDIT.md §2, §3 "Batch D"), and what only the owner can do.

## 1. What the owner does

### 1.1 Android: the signing fingerprint for `assetlinks.json`

1. Play Console → MyOtherApp → **Test and release → App integrity → App signing**.
2. Copy **"App signing key certificate" → SHA-256 certificate fingerprint**. Use the App Signing key, not the upload key: Play re-signs every install with it. To test a build you sign yourself, also copy the upload key's SHA-256 from the same page.
3. Vercel → project **moa-events** → Settings → Environment Variables → add `ANDROID_APP_SHA256` for **Production** (and Preview, if you test there). If you have more than one fingerprint, separate them with commas. Colons and letter case don't matter.
4. Deploy the site: after `feat/app-links` is merged, run `vercel deploy --prod` from the site's checkout. The value is read at build time, so a later change needs another deploy.

Until this is set, `https://myotherapp.in/.well-known/assetlinks.json` is `[]`. That is valid JSON, but it claims nothing, so Android opens the links in the browser.

### 1.2 iOS: Associated Domains on the App ID

1. developer.apple.com → Certificates, Identifiers & Profiles → **Identifiers** → `app.myotherapp.com` → tick **Associated Domains** → Save.
2. Profiles:
   - With Xcode's automatic signing, the next archive picks up the capability.
   - With manual profiles, regenerate the App Store distribution profile and the development profile, then download them again.

   The entitlement `applinks:myotherapp.in` is already in `ios/Runner/Runner.entitlements` and `Runner.Release.entitlements`. A profile without the capability fails code signing.

### 1.3 Checking both

**The site:**

```sh
curl -sI https://myotherapp.in/.well-known/apple-app-site-association   # 200, content-type: application/json, no location:
curl -s  https://myotherapp.in/.well-known/apple-app-site-association | jq .
curl -s  https://myotherapp.in/.well-known/assetlinks.json | jq .
```

**Apple:**
- What Apple's CDN serves to devices: `curl -s https://app-site-association.cdn-apple.com/a/v1/myotherapp.in | jq .`. It can lag the site by up to a day.
- Any AASA validator (for example Branch's) also works.
- On a phone with the new build:
  1. Paste `https://myotherapp.in/events/<a real slug>` into Notes, then long-press it. It should offer **Open in "MyOtherApp"**.
  2. With Developer Mode on: Settings → Developer → **Universal Links → Diagnostics** checks any URL against the installed app.

**Google:**
- Use the [Statement List Generator and Tester](https://developers.google.com/digital-asset-links/tools/generator): site `myotherapp.in`, package `app.myotherapp.com`, the SHA-256 → **Test statement**.
- Or ask the API directly:
  `curl -s "https://digitalassetlinks.googleapis.com/v1/statements:list?source.web.site=https://myotherapp.in&relation=delegate_permission/common.handle_all_urls"`
- On a phone with a Play-installed build:
  - `adb shell pm get-app-links app.myotherapp.com` should list `myotherapp.in: verified`.
  - `adb shell pm verify-app-links --re-verify app.myotherapp.com` re-checks.
  - Play Console → **Grow users → Deep links** shows the same.

### 1.4 Play Console declarations

- **App content → Advertising ID:** answer **No**. The app no longer has `com.google.android.gms.permission.AD_ID`, which Firebase used to merge in. It is removed in the manifest, along with the Privacy Sandbox ad permissions, and Analytics' ad-ID collection is turned off.
- **Data safety:** as `docs/RELEASE_1.1.0.md` §10. Analytics' app-instance ID is still collected; the advertising ID is not. Profile photos (camera or the system Photo Picker) are declared under Photos and videos.

### 1.5 Release signing

A release build now **fails** without `android/key.properties`. Before, it quietly signed with the debug key.

To try a release build on your own phone without the key, run `MOA_DEBUG_SIGNED_RELEASE=1 flutter run --release`, or put `moa.debugSignedRelease=true` in `~/.gradle/gradle.properties`. That opt-in is ignored on CI.

CI (`.github/workflows/ci.yml`) only analyzes and tests, so this doesn't affect it.

## 2. Links

The platforms hand the router the whole URL. The router's redirect reads it as the website's address first (`appLocationForLink` in `lib/app/router/web_links.dart`), so the site's `/events?…` opens Find events while the app's own `/events` stays the Events tab.

| Website | App |
| --- | --- |
| `/events?…` | `/discover/events?…`: batch A's Find events, with the same filters |
| `/events/{slug or id}` | the event's page. The route takes a string ref; until batch B's `buildEventPage` is wired in, a slug is looked up on `/discover/events/{slug}` |
| `/events/{ref}/live` | the event, with the live room opened over it |
| `/events/{ref}/register`, `/compete` | the same paths: batch B's registration and competition screens. Each asks for sign-in itself |
| `/clubs?…`, `/clubs/{slug or id}` | `/discover/clubs?…` (batch A); the club. Until batch C changes it, a slug is looked up on `/discover/clubs/{slug}` |
| `/threads`, `/threads/{id}` | `/discover/threads` (batch A); the post |
| `/tickets/{id}` | the ticket. Its QR is the ticket, so it works signed out and offline |
| `/certificates/{id}` | the person's own certificate, or the public page in the in-app browser |
| `/topics`, `/topics/{slug}` | the same paths (batch A) |
| `/feedback/{event}/{reg}?k=` | the same path: batch B's survey |
| `/claim/{token}` | the same path: a waiting list's offer (claim, pay, or pass it on). Opens signed out: the token is the proof. The `waitlist_offer` push opens it too |

- **Before batches A and B merge:** their addresses fall back to the Explore screens, Home, the event page, or (for the survey) a page that opens the website. Their own routes are spread just before the tab shell, so they are matched first and replace the fallbacks.
- **iPhone** opens all of these from the AASA. Only the live room, the feeds, `/play`, `/api`, `/og`, `/media`, `/for-clubs` and `/pricing` stay in the browser; the reasons are in the site's `src/seo/appLinks.js`. In short, the live room is the website's page in the app too, so claiming it only adds a hop for people scanning the room's QR.
- **Android** intent filters can't exclude a path, so the app also receives `…/live`. The router opens the event with its room.
- **Anything else** shows a "This page isn't in the app" screen, with **Open in browser** and **Go to Home**.
- **Only the apex domain** is claimed. `www.` and `events.` redirect to it, and Apple and Google don't follow redirects for these files.

**Signed out:**
- Home, Discover, events (including registration, the competition and the survey, which ask at their own actions), clubs, topics, posts, a ticket from its link, a waiting list's claim link, and certificates all open without an account.
- My events, My clubs, Profile, Settings, the inbox, badges, the certificates list and the scanner send the person to sign in (`/auth/onboarding?from=…`), then return to the page afterwards.
- `from` is only ever a path inside the app.
- Signed in on that screen, the person goes on to `/auth/profile-check?from=…`.
- The sign-in screen has **Not now**. When nothing is underneath it, Back does the same instead of closing the app.

## 3. iOS: the UIScene migration (not done yet)

**Why it matters:** Apple's TN3187 says apps built with the iOS 27 SDK must use the scene lifecycle or they won't launch. Xcode 26 builds are fine, so this must be done before moving to Xcode 27.

**Why it isn't done here:**
- It changes how the app launches, how pushes register, and how universal links arrive (`scene(_:continue:)` instead of the app delegate).
- None of that can be checked without a device build.

**Steps** (Flutter 3.44's own template, `packages/flutter_tools/templates/app/ios.tmpl`):

1. In `ios/Runner/AppDelegate.swift`:
   - Declare the class as `FlutterAppDelegate, FlutterImplicitEngineDelegate`.
   - Move plugin registration out of `didFinishLaunching` into:
     ```swift
     func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
       GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
     }
     ```
   - Keep everything else in `didFinishLaunching`: `FirebaseApp.configure()`, the `UNUserNotificationCenter` delegate, `registerForRemoteNotifications()` and the Messaging delegate. These are app-level and unaffected.
2. In `ios/Runner/Info.plist`, add the scene manifest:
   ```xml
   <key>UIApplicationSceneManifest</key>
   <dict>
     <key>UIApplicationSupportsMultipleScenes</key><false/>
     <key>UISceneConfigurations</key>
     <dict>
       <key>UIWindowSceneSessionRoleApplication</key>
       <array>
         <dict>
           <key>UISceneClassName</key><string>UIWindowScene</string>
           <key>UISceneConfigurationName</key><string>flutter</string>
           <key>UISceneDelegateClassName</key><string>FlutterSceneDelegate</string>
           <key>UISceneStoryboardFile</key><string>Main</string>
         </dict>
       </array>
     </dict>
   </dict>
   ```
   `FlutterSceneDelegate` can be named directly. The template's empty `SceneDelegate.swift` subclass is only needed for custom scene code, and adding it means editing the Xcode project.
3. Check each of these on a device:
   - cold start;
   - a push tapped while the app is closed, and while it is open;
   - a universal link tapped while the app is closed (it arrives as a scene connection option) and while it is open;
   - Google sign-in (`google_sign_in_ios` presents from `keyWindow.rootViewController`, which still works with scenes);
   - Sign in with Apple;
   - Razorpay checkout and the UPI app switch;
   - Add to calendar (`add_2_calendar` uses `keyWindow`);
   - sharing a ticket PDF and opening it (`share_plus`, `open_filex`);
   - the QR scanner;
   - Apple Wallet.

   The plugins reviewed on 2026-10-19 get their view controller from `keyWindow`, `connectedScenes` or the registrar, never from `UIApplicationDelegate.window`, so none is expected to break.

## 4. Android: checking 16 KB pages

Play requires 16 KB-aligned native libraries for apps targeting Android 15+. Only 64-bit ABIs matter.

**What was checked on 2026-10-19, without a build:**
- **ML Kit barcode** (`com.google.mlkit:barcode-scanning:17.3.0`, bundled by `mobile_scanner` 7.1.4): `libbarhopper_v3.so` is aligned to `0x4000` (16 KB) for `arm64-v8a` and `x86_64`. The 32-bit copies are 4 KB, which is allowed.
- **Razorpay** (`checkout` 1.6.41, `standard-core` 1.7.20, `gpay`): no native libraries at all.
- **Flutter 3.44's engine and the app's own `libapp.so`** are built 16 KB-aligned (NDK 28.2).

To check a library yourself:

```sh
NDK=$ANDROID_HOME/ndk/28.2.13676358/toolchains/llvm/prebuilt/darwin-x86_64/bin
unzip -o some.aar 'jni/*' -d /tmp/aar
$NDK/llvm-readelf -lW /tmp/aar/jni/arm64-v8a/*.so | grep LOAD   # last column must be 0x4000 or more
```

**On the real release bundle** (the authoritative check):

```sh
flutter build appbundle --release            # needs android/key.properties
BT=bundletool-all.jar                        # https://github.com/google/bundletool/releases
java -jar $BT build-apks --bundle=build/app/outputs/bundle/release/app-release.aab \
  --output=/tmp/app.apks --mode=universal
unzip -o /tmp/app.apks universal.apk -d /tmp/apks
$ANDROID_HOME/build-tools/36.0.0/zipalign -c -P 16 -v 4 /tmp/apks/universal.apk   # "Verification successful"
```

**Other ways to check:**
- Upload the bundle to an internal testing track. Play Console → **App bundle explorer** → the bundle → **Memory page size** must say **Supports 16 KB**.
- Android Studio's APK Analyzer flags unaligned `.so` files.
- If ML Kit ever fails the check, set `dev.steenbakker.mobile_scanner.useUnbundled=true` in `android/gradle.properties`. That uses the Play Services model, which has no `.so` in the APK.

## 5. Android toolchain

| | Was | Now |
| --- | --- | --- |
| compileSdk / targetSdk | `flutter.*` (36 on Flutter 3.44, 35 on older SDKs) | pinned at **36** |
| Android Gradle Plugin | 8.6.0 | **8.11.1** |
| Gradle | 8.7 | **8.14.3** |
| Kotlin Gradle Plugin | 2.1.0 | **2.2.20** |

These are what Flutter 3.44's version checker asks for: it warns below AGP 8.11.1, Gradle 8.14 and KGP 2.2.20. It is also the newest AGP/KGP pair Kotlin documents as compatible. Flutter's own template has moved to AGP 9 and Gradle 9.1. That move changes the Kotlin plugin setup and is left for later.

## 6. Notifications

**Icon and channel:**
- Pushes show the white status-bar icon `@drawable/ic_stat_notification` in teal, on the channel `high_importance_channel`. The channel is now named **"Events and clubs"** in Settings.
- The manifest names both as FCM's defaults, so pushes the system shows while the app is in the background use them too. Before, they used the launcher icon and the "Miscellaneous" channel.
- **Optional backend change:** set `android.notification.channel_id = "high_importance_channel"` on sends.

**Links in pushes:**
- A push may carry a `url`. A website address the app has opens its screen there, including the feedback survey.
- Anything else opens in the browser; this works on taps while the app is running. A cold start from such a push opens just the app.
- Known types (`event_*`, `club_thread`) keep their own routes, and `push_id` still de-duplicates.

**Icon files:** made by `tool/icons.py`, which also flattens the iOS icons:
- `python3 tool/icons.py check` reports any icon that is out of date.
- `python3 tool/icons.py ios` and `python3 tool/icons.py android` regenerate them.
