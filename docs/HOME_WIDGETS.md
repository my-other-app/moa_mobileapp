# Home-screen widgets and the icon's shortcuts

The app has two home-screen widgets on Android and iOS, and four shortcuts
on its icon:

* **Next up** – the person's next event.
* **Networking** – their QR code to share, and a quick way to scan someone.
* **Shortcuts** (touch and hold the app's icon): **Scan**, **My QR**,
  **Network**, **My tickets**.

Both widgets come in two sizes, small and medium, light and dark (they
follow the phone), in the app's colours – ink `#2C333D`, the tabs' pale
yellow `#F9FFA1`, the icon's teal `#17A58F`, soft grey `#F3F3F3` – and its
fonts (see [Fonts](#fonts)).

## Next up

| What they have | What the widget shows | A tap opens |
| --- | --- | --- |
| A ticket (registered or confirmed) to an event that isn't over | The soonest one: date block, name, "Today · 9:30 am" / "Tomorrow · 9:30 am" / "In 3 days" / "Happening now"; medium adds the time, the venue (or "Online") and **Show ticket ›** | That ticket (`/events/{id}/ticket`) |
| No ticket, a registration under review | The same, labelled **Under review** (or **Payment due** for a confirmed paid place not paid yet); the club in place of the venue | The event's page |
| Nothing coming up | "Nothing coming up yet" + **Find events** | Discover → Find events |
| Signed out (or the app not opened since install) | "Sign in to see your next event" + **Sign in** | Sign-in, then My events |

**Small** (2×2: the date block, the name and the relative line) and
**medium** (4×2: adds the time and the place, and the Show ticket pill).

All dates and times are **India time (Asia/Kolkata)**, whatever the phone's
time zone, as on the website.

## Networking

| State | Small (2×2) | Medium (4×2) | A tap opens |
| --- | --- | --- | --- |
| Signed in, code read | The QR code, large enough to scan, the name under it | The code on the left; the name, "Scan to save me", a **Scan** pill and **Network · 12 ›** on the right | The code / the card: **My QR** full screen. Scan: the scanner that saves a person. Network: the Network tab |
| Signed in, no code read yet (the app hasn't opened My QR, or the first run was offline) | A soft placeholder where the code goes, "Tap for your QR" | The placeholder; the name, "Open My QR to get your code", Scan and Network | My QR, which makes the code (`GET /me/qr` makes it on the first ask) |
| Signed out (or the app not opened since install) | "Sign in to share your QR" + **Sign in** | The placeholder; "Sign in to share your QR" + **Sign in** | Sign-in, then My QR |

* The code is **always dark on white with a four-module quiet zone**, in
  the dark theme too, and is drawn by the widget from the stored link (iOS:
  CoreImage's QR generator; Android: ZXing's encoder), error correction M.
  For a profile link (`https://myotherapp.in/p/<10 letters>`) that is a
  29×29-module code.
* **Never on the lock screen.** Android: `widgetCategory="home_screen"`
  only. iOS: home-screen families only (no lock-screen families); the code
  and the name are `privacySensitive` (hidden while the phone is locked,
  e.g. in StandBy) and the widget is not suggested for StandBy
  (`disfavoredLocations`, iOS 17).
* Gallery name and description: **"Networking"** / **"Your QR code to
  share, and quick scan."** Android places it at 2×2; widen it to about 4
  cells for the medium layout.
* My QR is the app's `/profile/qr` (`myQrLocation`).

## Shortcuts on the app's icon

Touch and hold the icon:

| Shortcut | Opens | iOS symbol |
| --- | --- | --- |
| **Scan** | The scanner that saves a person (`/network/scan`) | `qrcode.viewfinder` |
| **My QR** | My QR, full screen (`/profile/qr`) | `qrcode` |
| **Network** | The Network tab (`/network`) | `person.2` |
| **My tickets** | My events and tickets (`/events`) | `ticket` |

Each opens a website address – `https://myotherapp.in/network/scan`,
`/profile/qr`, `/network`, `/me/tickets` – exactly as a widget's tap does
(below): the router reads it as the app's own page, and signed out the
person signs in first and then lands on it.

* **iOS**: static quick actions, `UIApplicationShortcutItems` in
  `ios/Runner/Info.plist` (there from install), each with its address in
  `UIApplicationShortcutItemUserInfo.link`. `AppDelegate`
  (`application(_:performActionFor:)`) opens it through Flutter's deep
  linking; it accepts only `https://myotherapp.in/…` addresses.
* **Android**: dynamic shortcuts published at each launch
  (`AppShortcuts.kt`, from `MainActivity.onCreate`), so they appear once the
  app has been opened. Not manifest shortcuts: Android launches those with
  `FLAG_ACTIVITY_CLEAR_TASK`, which would restart the app from its splash
  screen; these bring the running app forward and open the page in it.
  Labels and links: `res/values/app_shortcuts.xml`; icons: adaptive icons
  (`res/drawable-anydpi-v26/ic_shortcut_*.xml`, the glyph on the pale
  yellow) with a round fallback for Android 7.1.
* A test (`test/features/home_widget/app_shortcuts_test.dart`) holds both
  lists to the same four links in the same order, and each link to its page.

## How it works

```
saved tickets, registrations under review ─▶ HomeWidgetSyncScope ─────▶ nextUpFrom() ──▶ JSON "next_up"
signed in?                                   (main shell)

My QR's code (lastKnownQrProvider)  ─┐
the name (public profile / account) ─┼─▶ NetworkingWidgetSyncScope ─▶ NetworkingSnapshot ─▶ JSON "networking"
the network's size (knownNetwork…)  ─┤   (main shell)
signed in?                          ─┘
                                                         │
             home_widget: saveWidgetData(key) + updateWidget
               Android: SharedPreferences "HomeWidgetPreferences"
               iOS:     UserDefaults(suiteName: group.app.myotherapp.in)
                                                         │
      Android: NextUpWidgetProvider / NetworkingWidgetProvider (RemoteViews)
      iOS:     NextUpWidget / NetworkingWidget (WidgetKit, one WidgetBundle)
```

* **Dart** (`lib/features/home_widget/`)
  * `data/widget_store.dart` – `WidgetStore` / `HomeWidgetStore`, the
    home_widget calls for one kind of widget (App Group, data key, iOS kind,
    Android provider), and which kind is on a home screen. A no-op off the
    phone (tests). `next_up_store.dart` and `networking_store.dart` name each
    kind (`NextUpKind`, `NetworkingKind`).
  * `domain/next_up.dart` – `nextUpFrom()` picks what Next up shows;
    `nextUpWhen()` is the rule for the relative line.
  * `domain/networking.dart` – `NetworkingSnapshot.from()` and its JSON;
    `isProfileQrLink()`; `networkingLinks` (the taps).
  * `presentation/home_widget_sync.dart`, `networking_widget_sync.dart` –
    the syncs (each writes, and skips a write identical to the last) and
    their scopes in the main shell.
* **When Next up is written**: app start (once the saved tickets are read);
  resume; a registration; a ticket gone from the server's list (on the next
  refresh of the saved tickets); a registration sent for review or
  withdrawn; sign-in. When a Next up widget is on a home screen the app also
  reads the registrations under review (at most every 10 minutes).
* **When Networking is written**: when My QR reads the code (`GET /me/qr`,
  `myQrProvider`) or replaces it (`POST /me/qr/replace`: the new link at
  once, before My QR reads it back); sign-in and sign-out; when the name
  changes (the public profile, else the account's profile, once read); when
  a page of the whole network (no search or filter) is read. Without a
  Networking widget on a home screen this asks the server nothing more than
  the screens do. **With one placed** (and someone signed in) the app reads
  for it, on start and on each return: the code (`GET /me/qr`, which makes
  one on the first ask – the person put their QR on their home screen), the
  account's profile, and the network's size (`GET /network?page_size=1`),
  kept current through saves, removals and blocks (each reads the network
  again) and read again at most every 10 minutes on a return.
* **Sign-out** (and a session the server ended, and sign-in) writes both
  widgets' signed-out state through `SessionCaches`, with everything else
  kept about the person.
* **The taps** open the website's address, e.g.
  `https://myotherapp.in/events/12/ticket` or
  `https://myotherapp.in/profile/qr`. Both apps hand it to Flutter's deep
  linking (Android: an explicit intent to `MainActivity`; iOS: `widgetURL` /
  `Link`, delivered to `application(_:open:)`), and the router reads it with
  `appLocationForLink` as it reads the site's links. These addresses need an
  account (`route_access.dart`): signed out, sign-in comes first and returns
  to the page. They don't depend on universal links or App Links (the
  website's app-links file doesn't claim `/network` or `/profile`).

### What is in the shared storage

That storage can be read by anyone holding the phone, so it holds only what
the widgets show and where a tap goes. Neither widget's storage is in
Android's backups (`backup_rules.xml`, `data_extraction_rules.xml`).

**Next up** (`next_up`, version 1):

```json
{
  "v": 1,
  "state": "upcoming",              // or "nothing", "signed_out"
  "link": "https://myotherapp.in/events",
  "items": [{
    "event_id": 12,
    "name": "Hack Night 04",
    "starts_at": 1763094600000,      // epoch ms; absent when no date
    "ends_at": 1763105400000,        // start + length (a day if unknown)
    "weekday": "SAT", "day": "14", "month": "NOV",
    "time": "9:30 am", "date": "Sat, 14 Nov",   // India time
    "place": "Maker Space, Kochi",   // or "Online"; absent if unknown
    "club": "Kochi Coders",
    "review": false,
    "badge": "Under review",         // only for review items
    "when": "Tomorrow · 9:30 am",    // as of writing; the widgets recompute
    "link": "https://myotherapp.in/events/12/ticket"
  }]
}
```

**Never** the ticket code (it is what the QR encodes, and the door lets in
whoever shows it), the ticket's URL, a registration's status token, a claim
token or any session token. Up to four events are written, so the widget
can move on to the next one when one ends while the app stays closed.

**Networking** (`networking`, version 1):

```json
{
  "v": 1,
  "state": "ready",                 // or "no_qr", "signed_out"
  "name": "Asha Menon",             // absent if unknown, and signed out
  "profile_link": "https://myotherapp.in/p/abcdefghjk",   // only "ready"
  "network": 12,                    // absent until a page of the network is read
  "links": {
    "qr": "https://myotherapp.in/profile/qr",
    "scan": "https://myotherapp.in/network/scan",
    "network": "https://myotherapp.in/network"
  }
}
```

Only the **public profile link from `/me/qr`** (what the QR encodes) is
stored – and only when it is a personal QR's link
(`https://myotherapp.in/p/<code>`), never anything else; it is replaced at
once when the person replaces their code, and gone at sign-out. Never an
email, a phone number, a ticket, a token or anyone else's details. Signed
out, only `v`, `state` and `links`. Tests hold the JSON to these fields
(`test/features/home_widget/networking_widget_test.dart`).

### Keeping "Today / Tomorrow / In 3 days" right

The Next up widgets compute the relative line themselves at draw time, on
India's clock (`IndiaClock` in `NextUpData.kt` and `NextUpData.swift`, the
same rules as `nextUpWhen` in Dart), and skip events that have ended.

* **Android**: every draw books the next redraw – the next midnight in
  India, or an event's start or end before it – through home_widget's
  `HomeWidgetScheduler` (an inexact alarm; no exact-alarm permission). Its
  `HomeWidgetScheduledUpdateReceiver` is in the manifest, with
  `RECEIVE_BOOT_COMPLETED` so the alarm survives a restart.
  `updatePeriodMillis` (hourly) is the backstop.
* **iOS**: the `TimelineProvider` returns an entry for now and for each
  change in the next seven days (each midnight in India, each event's start
  and end), with the `.atEnd` policy. The app reloads the timeline whenever
  it writes.

Networking doesn't change with the clock: one entry (iOS, `.never`), no
periodic update (Android); the app redraws it whenever it writes.

## Fonts

The app's fonts are **DM Sans** (text; one variable font,
`assets/fonts/DMSans-VariableFont_opsz,wght.ttf`) and **Bebas Neue**
(display numbers; `assets/fonts/BebasNeue-Regular.ttf`).

* **iOS – both, everywhere.** The extension carries the two files, copied
  at build time from `assets/fonts/` (the Xcode project references them
  there; one copy in the repository) and registered by `UIAppFonts` in
  `ios/NextUpWidget/Info.plist`. `WidgetFonts` (`WidgetStyle.swift`) asks for
  the family (`DM Sans`, `Bebas Neue`) and sets DM Sans's weight on its
  `wght` axis (400 regular, 600 semibold), at the font's default optical
  size, as the app's text is drawn. (A name lookup such as
  `DMSans-SemiBold` would land on a named instance at another optical size;
  the file's instances are named `DMSans-9ptRegular_*`.) If a family can't
  be found, the system font is used at the same size and weight. Next up's
  date block is Bebas Neue; all other text DM Sans.
* **Android – Bebas Neue for the date block; text in the system's
  sans-serif.** A widget's layout is inflated by the launcher in a
  restricted context, and there TextView ignores a font resource
  (`android:fontFamily="@font/…"` silently falls back to the default) – on
  every Android version that has font resources (8.0 onwards; see
  `Context.CONTEXT_RESTRICTED` and TextView's `fontFamily` handling). Older
  versions (7.x, our minimum is 7.0) have no font resources at all. So the
  widgets' text uses `sans-serif` / `sans-serif-medium` on every version,
  and Next up's date block – three short words – is drawn in Bebas Neue into
  a bitmap by the provider in the app's own process (`WidgetType.kt`),
  where custom typefaces work on every version; the font file is read from
  the app's Flutter assets (`flutter_assets/assets/fonts/…`), with a
  condensed bold system face as the fallback.
* `test/features/home_widget/widget_fonts_test.dart` holds the font files,
  `pubspec.yaml`, `Info.plist`, the Xcode project and the Android asset path
  to the same files.

## Files

* **Android**: `android/app/src/main/kotlin/app/myotherapp/com/widget/`
  (`NextUpWidgetProvider.kt`, `NextUpData.kt`, `NetworkingWidgetProvider.kt`,
  `NetworkingData.kt`, `QrBitmap.kt`, `WidgetType.kt`),
  `AppShortcuts.kt` and `MainActivity.kt`,
  `res/layout/widget_{next_up,networking}_{small,medium,preview}.xml`,
  `res/xml/{next_up,networking}_widget_info.xml`,
  `res/drawable/widget_*.xml`, `res/drawable*/ic_shortcut_*.xml`,
  `res/values{,-night}/widget_{next_up,networking}.xml`,
  `res/values/app_shortcuts.xml`, and the receivers plus
  `RECEIVE_BOOT_COMPLETED` in `AndroidManifest.xml`. The Kotlin package is
  `app.myotherapp.com` (the namespace), so the Dart side names the
  providers by their full class names. One new dependency:
  `com.google.zxing:core` (the QR encoder; Apache 2.0, plain Java, no
  dependencies; R8 keeps only what is used).
* **iOS**: `ios/NextUpWidget/` – `WidgetBundle.swift` (the `@main` bundle:
  Next up and Networking), `WidgetStyle.swift` (palette, fonts, pill),
  `NextUpWidget.swift`, `NextUpData.swift`, `NetworkingWidget.swift`,
  `NetworkingData.swift`, `QRCode.swift`, `Info.plist`,
  `NextUpWidget.entitlements`, `PrivacyInfo.xcprivacy`,
  `NextUpWidget.xcconfig` – the target in `ios/Runner.xcodeproj`, the App
  Group in `ios/Runner/Runner.entitlements` and `Runner.Release.entitlements`,
  the App Group reason (`1C8F.1`) in `ios/Runner/PrivacyInfo.xcprivacy`, and
  the quick actions in `ios/Runner/Info.plist` + `AppDelegate.swift`.
* The Xcode target is added by **`tool/ios_add_widget_extension.rb`**
  (`ruby tool/ios_add_widget_extension.rb`; it needs the `xcodeproj` gem
  that comes with CocoaPods). It is safe to run again; run it after adding
  a Swift file to `ios/NextUpWidget/` (and add the file to its `SOURCES`).
  It:
  * raises the app's deployment target from iOS 13.0 to **14.0** (project
    and Podfile) – WidgetKit and the home_widget plugin need iOS 14, and
    every iPhone that ran iOS 13 can run 14;
  * adds the `NextUpWidget` app-extension target: bundle id
    `app.myotherapp.in.NextUpWidget`, Runner's team (`PX6QV826X4`),
    automatic signing, iPhone only, iOS 14.0, version and build number from
    Flutter (`FLUTTER_BUILD_NAME` / `FLUTTER_BUILD_NUMBER`, so they always
    match the app's), its Swift files and the two fonts;
  * embeds it in Runner ("Embed Foundation Extensions", placed before "Thin
    Binary" – after it Xcode reports a dependency cycle) and makes Runner
    depend on it.

  After it: `flutter pub get && (cd ios && pod install)`.
* Every widget lives in this **one** extension (the target keeps its first
  name, `NextUpWidget`), so new widgets need no new App ID, App Group or
  profile. Newer pieces are gated with `@available` (lock-screen families
  iOS 16, buttons in widgets iOS 17, Controls iOS 18).

## Owner steps (Apple) – before the next iOS release

**Nothing new for Networking or the shortcuts**: the Networking widget is
in the same extension, App ID and App Group as Next up, and quick actions
need no capability. The steps below are the ones Next up already needs; do
them once.

The App Group and the extension's App ID have to exist in the Apple
Developer account before a **release** build can be signed. Debug builds on
the simulator need nothing.

1. **Register the App Group.** developer.apple.com → Certificates,
   Identifiers & Profiles → Identifiers → **+** → **App Groups** →
   Description "MyOtherApp", Identifier **`group.app.myotherapp.in`** →
   Register.
2. **Add App Groups to the app's App ID.** Identifiers → **App IDs** →
   `app.myotherapp.in` → tick **App Groups** → **Configure** → tick
   `group.app.myotherapp.in` → Continue → **Save** (confirm the warning that
   profiles become invalid). Leave Push Notifications, Sign in with Apple
   and Associated Domains as they are.
3. **Register the widget's App ID.** Identifiers → **+** → **App IDs** →
   App → Description "MyOtherApp widgets", **Explicit** Bundle ID
   **`app.myotherapp.in.NextUpWidget`** → tick **App Groups** → Configure →
   `group.app.myotherapp.in` → Continue → Register. No other capability.
4. **Profiles.**
   * The project uses **automatic signing** (team `PX6QV826X4`). Open
     `ios/Runner.xcworkspace` in Xcode, signed in with the team's account:
     Runner → Signing & Capabilities shows **App Groups** with
     `group.app.myotherapp.in` ticked; NextUpWidget → the same team,
     "Automatically manage signing". Xcode then makes the development
     profiles, and Product → Archive → Distribute makes the App Store ones
     for both bundle ids.
   * If release builds are signed with **manual** profiles instead (a
     downloaded "App Store" profile, fastlane match or CI): regenerate the
     App Store profile for `app.myotherapp.in` (it now carries App Groups),
     and create one for `app.myotherapp.in.NextUpWidget` (Profiles → **+** →
     App Store Connect → that App ID → the distribution certificate).
     Install both; the archive needs one per bundle id.
5. **App Store Connect**: nothing to set up – the widgets ship inside the
   app. The app's minimum iOS becomes 14.0 with this build.

Until steps 1–4 are done a release archive fails to sign ("Provisioning
profile doesn't include the com.apple.security.application-groups
entitlement" / "No profile for app.myotherapp.in.NextUpWidget").

**Android**: nothing to set up. The widgets and shortcuts ship in the app.

## Trying it

**iPhone (device or simulator)**

1. `flutter run` (a device needs steps 1–4, or Xcode's automatic signing
   with a team account that may register them).
2. Home screen → touch and hold → **Edit** → **Add Widget** → search
   "MyOtherApp" → **Next up** or **Networking** → pick Small or Medium →
   Add Widget.
3. Next up: signed out it says "Sign in to see your next event"; sign in
   and it shows the next ticket (or "Nothing coming up yet"). Register for
   an event and go back to the home screen: it shows it. Tap: the app opens
   on the ticket.
4. Networking: signed out, "Sign in to share your QR". Sign in and open the
   app once: the widget reads the code and shows it (offline the first
   time: the placeholder, which opens My QR). Scan it with another phone's
   camera: it opens the profile. Medium: Scan opens the scanner, "Network ·
   N" the Network tab, the code My QR. My QR → ⋮ → Replace code: the widget
   shows the new code. Save someone: the count moves on.
5. Touch and hold the app's icon: Scan, My QR, Network, My tickets; each
   opens its page (signed out: sign-in first, then the page).
6. Settings → Display & Brightness → Dark: the dark colours (the code stays
   dark on white).
7. Sign out: both widgets ask to sign in again.

**Android**

1. `flutter run` (or install the debug APK).
2. Home screen → touch and hold → **Widgets** → **MyOtherApp** → **Next
   up** (placed at 4×2; resize to 2×2 for the small layout) or
   **Networking** (placed at 2×2; widen it to 4 cells for the medium one).
3. The same checks as above; dark theme from Quick Settings. Shortcuts:
   touch and hold the icon (after the app has been opened once).
4. To redraw a widget while testing, open the app and leave it again: every
   resume redraws the widgets, and every change the app sees rewrites them.

**Relative line**: register for an event starting in a few minutes; Next up
says "Today · …", and "Happening now" from its start (iOS at the timeline
entry; Android at the booked alarm, which may be a few minutes late), then
moves on to the next event once it ends.

### Previews

`tool/widget_previews/render.sh [out-dir]` draws the iOS widgets' views
(both widgets, both sizes, every state, light and dark) to PNG on a Mac,
with the app's fonts – a quick look without a phone. The Android layouts
are checked on a phone or emulator.
