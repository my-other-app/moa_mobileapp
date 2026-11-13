# Home-screen widgets: "Next up"

The app has one home-screen widget on Android and iOS, **Next up**: the
person's next event.

| What they have | What the widget shows | A tap opens |
| --- | --- | --- |
| A ticket (registered or confirmed) to an event that isn't over | The soonest one: date block, name, "Today · 9:30 am" / "Tomorrow · 9:30 am" / "In 3 days" / "Happening now"; medium adds the time, the venue (or "Online") and **Show ticket ›** | That ticket (`/events/{id}/ticket`) |
| No ticket, a registration under review | The same, labelled **Under review** (or **Payment due** for a confirmed paid place not paid yet); the club in place of the venue | The event's page |
| Nothing coming up | "Nothing coming up yet" + **Find events** | Discover → Find events |
| Signed out (or the app not opened since install) | "Sign in to see your next event" + **Sign in** | Sign-in, then My events |

Two sizes: **small** (2×2: the date block, the name and the relative line)
and **medium** (4×2: adds the time and the place, and the Show ticket pill).
Light and dark follow the phone. Colours are the app's: ink `#2C333D`, the
tabs' pale yellow `#F9FFA1` and the icon's teal `#17A58F`.

All dates and times are **India time (Asia/Kolkata)**, whatever the phone's
time zone, as on the website.

## How it works

```
saved tickets (savedTicketsProvider) ─┐
registrations under review ───────────┼─▶ HomeWidgetSyncScope ─▶ nextUpFrom() ─▶ JSON
signed in? (isAuthenticatedProvider) ─┘     (main shell)          (pure Dart)      │
                                                                                   ▼
                                       home_widget: saveWidgetData('next_up') + updateWidget
                                         Android: SharedPreferences "HomeWidgetPreferences"
                                         iOS:     UserDefaults(suiteName: group.app.myotherapp.in)
                                                                                   │
                         NextUpWidgetProvider.kt (RemoteViews)  ◀──────────────────┤
                         NextUpWidget.swift (WidgetKit)         ◀──────────────────┘
```

* **Dart** (`lib/features/home_widget/`)
  * `domain/next_up.dart` – `nextUpFrom()` picks what to show and builds the
    JSON; `nextUpWhen()` is the rule for the relative line; India-time
    formatting. Unit-tested in `test/features/home_widget/`.
  * `data/next_up_store.dart` – `NextUpStore`, the home_widget calls
    (App Group id, data key, iOS kind, Android provider class). A no-op off
    the phone (tests).
  * `presentation/home_widget_sync.dart` – `HomeWidgetSync` (writes, skips a
    write identical to the last) and `HomeWidgetSyncScope`, which sits in
    the main shell next to `SavedTicketsSync`. It writes once the saved
    tickets have been read at start-up, then whenever the tickets, the
    registrations under review or the session change, and redraws the
    widgets each time the app comes back to the front. When a widget is on
    a home screen it also reads the registrations under review (at most
    every 10 minutes), which otherwise only My events reads.
* **When it is written**: app start (once the saved tickets are read);
  resume; a registration (the form now refreshes the saved tickets, as a
  claimed or confirmed place already did); a ticket gone from the server's
  list (cancelled, refunded, revoked – on the next refresh of the saved
  tickets: My events, a resume after 10 minutes, coming back online); a
  registration sent for review or withdrawn; sign-in. **Sign-out** (and a
  session the server ended) writes the signed-out state through
  `SessionCaches`, with everything else kept about the person.
* **The tap** opens the website's address, e.g.
  `https://myotherapp.in/events/12/ticket`. Both apps hand it to Flutter's
  deep linking (Android: an explicit intent to `MainActivity`; iOS:
  `widgetURL`, delivered to `application(_:open:)`), and the router reads
  it with `appLocationForLink` as it reads the site's links. The new route
  `/events/:eventId/ticket` (`EventTicketPage`) finds the ticket among the
  tickets saved on the phone – reading the list again once if it isn't
  there – and shows it; with no ticket it shows the event's page. It needs
  an account (`route_access.dart`): signed out, sign-in comes first and
  returns to it.

### What is in the shared storage

Only what the widget shows and where a tap goes. The JSON (version 1):

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
token or any session token. A test holds the JSON to that. Up to four events
are written, so the widget can move on to the next one when one ends while
the app stays closed.

### Keeping "Today / Tomorrow / In 3 days" right

The widgets compute the relative line themselves at draw time, on India's
clock (`IndiaClock` in `NextUpData.kt` and `NextUpData.swift`, the same rules
as `nextUpWhen` in Dart), and skip events that have ended.

* **Android**: every draw books the next redraw – the next midnight in
  India, or an event's start or end before it – through home_widget's
  `HomeWidgetScheduler` (an inexact alarm; no exact-alarm permission). Its
  `HomeWidgetScheduledUpdateReceiver` is in the manifest, with
  `RECEIVE_BOOT_COMPLETED` so the alarm survives a restart.
  `updatePeriodMillis` (hourly) is the backstop.
* **iOS**: the `TimelineProvider` returns an entry for now and for each
  change in the next seven days (each midnight in India, each event's
  start and end), with the `.atEnd` policy. The app reloads the timeline
  (`WidgetCenter.reloadTimelines(ofKind: "NextUpWidget")`) whenever it
  writes.

## Files

* Android: `android/app/src/main/kotlin/app/myotherapp/com/widget/`
  (`NextUpWidgetProvider.kt`, `NextUpData.kt`),
  `res/layout/widget_next_up_{small,medium,preview}.xml`,
  `res/xml/next_up_widget_info.xml`, `res/drawable/widget_next_up_*.xml`,
  `res/values{,-night}/widget_next_up.xml`, and two receivers plus
  `RECEIVE_BOOT_COMPLETED` in `AndroidManifest.xml`. One resizable widget:
  placed at 4×2 (medium), shrinks to 2×2 (small). The Kotlin package is
  `app.myotherapp.com` (the namespace), so the Dart side names the provider
  by its full class name.
* iOS: `ios/NextUpWidget/` (`NextUpWidget.swift`, `NextUpData.swift`,
  `Info.plist`, `NextUpWidget.entitlements`, `PrivacyInfo.xcprivacy`,
  `NextUpWidget.xcconfig`), the target in `ios/Runner.xcodeproj`, the App
  Group in `ios/Runner/Runner.entitlements` and `Runner.Release.entitlements`,
  and the App Group reason (`1C8F.1`) in `ios/Runner/PrivacyInfo.xcprivacy`.
* The Xcode target is added by **`tool/ios_add_widget_extension.rb`**
  (`ruby tool/ios_add_widget_extension.rb`; it needs the `xcodeproj` gem
  that comes with CocoaPods). It is safe to run again. It:
  * raises the app's deployment target from iOS 13.0 to **14.0** (project
    and Podfile) – WidgetKit and the home_widget plugin need iOS 14, and
    every iPhone that ran iOS 13 can run 14;
  * adds the `NextUpWidget` app-extension target: bundle id
    `app.myotherapp.in.NextUpWidget`, Runner's team (`PX6QV826X4`),
    automatic signing, iPhone only, iOS 14.0, version and build number from
    Flutter (`FLUTTER_BUILD_NAME` / `FLUTTER_BUILD_NUMBER`, so they always
    match the app's);
  * embeds it in Runner ("Embed Foundation Extensions", placed before "Thin
    Binary" – after it Xcode reports a dependency cycle) and makes Runner
    depend on it.

  After it: `flutter pub get && (cd ios && pod install)`.

## Owner steps (Apple) – before the next iOS release

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
   App → Description "MyOtherApp Next up widget", **Explicit** Bundle ID
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
5. **App Store Connect**: nothing to set up – the widget ships inside the
   app. The app's minimum iOS becomes 14.0 with this build.

Until steps 1–4 are done a release archive fails to sign ("Provisioning
profile doesn't include the com.apple.security.application-groups
entitlement" / "No profile for app.myotherapp.in.NextUpWidget").

## Trying it

**iPhone (device or simulator)**

1. `flutter run` (a device needs steps 1–4, or Xcode's automatic signing
   with a team account that may register them).
2. Home screen → touch and hold → **Edit** → **Add Widget** → search
   "MyOtherApp" → **Next up** → pick Small or Medium → Add Widget.
3. Signed out it says "Sign in to see your next event"; sign in and it
   shows the next ticket (or "Nothing coming up yet"). Register for an
   event and go back to the home screen: it shows it. Tap: the app opens
   on the ticket.
4. Settings → Display & Brightness → Dark: the dark colours.
5. Sign out: the widget asks to sign in again.

**Android**

1. `flutter run` (or install the debug APK).
2. Home screen → touch and hold → **Widgets** → **MyOtherApp** → **Next
   up** → drag it to the home screen (4×2). Resize it to 2×2 for the small
   layout.
3. The same checks as above; dark theme from Quick Settings.
4. To redraw it while testing, open the app and leave it again: every
   resume redraws the widget, and every change the app sees rewrites it.

**Relative line**: register for an event starting in a few minutes; the
widget says "Today · …", and "Happening now" from its start (iOS at the
timeline entry; Android at the booked alarm, which may be a few minutes
late), then moves on to the next event once it ends.
