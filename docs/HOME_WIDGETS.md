# Home-screen widgets and the icon's shortcuts

The app has two home-screen widgets on Android and iOS, lock-screen
widgets on the iPhone, **Scan** and **My QR** buttons for the phone's own
quick places, and four shortcuts on its icon:

* **Next up** – the person's next event (small, medium); the next three
  (large); on the iPhone's lock screen as a card, a line or a round date.
* **Networking** – their QR code to share, and a quick way to scan someone
  (small, medium); large adds **Recently met**, the people they met last.
* **My QR** on the iPhone's lock screen – a round button that opens the code
  (no code is drawn there).
* **Controls** (iPhone, iOS 18) and **Quick Settings tiles** (Android):
  **Scan** and **My QR**.
* **Shortcuts** (touch and hold the app's icon): **Scan**, **My QR**,
  **Network**, **My tickets**.

| Piece | iPhone | Android | Added by the person |
| --- | --- | --- | --- |
| Next up, small / medium / large | iOS 14 | 2×2 / 4×2 / about 4×4 | Home screen → Add widget |
| Next up, lock screen (card, line, round) | iOS 16 | – | Lock screen → Customize → Add widgets |
| Networking, small / medium / large | iOS 14 | 2×2 / 4×2 / about 4×4 | Home screen → Add widget |
| My QR, lock screen (round) | iOS 16 | – | Lock screen → Customize → Add widgets |
| Scan, My QR controls | iOS 18 | – | Control Center, the lock screen's buttons, the Action button |
| Scan, My QR tiles | – | Android 7+ | Quick Settings → Edit |
| Icon shortcuts | iOS 14 | Android 7.1+ | Touch and hold the icon |

The home-screen widgets come light and dark (they follow the phone), in the
app's colours – ink `#2C333D`, the tabs' pale yellow `#F9FFA1`, the icon's
teal `#17A58F`, soft grey `#F3F3F3` – and its fonts (see [Fonts](#fonts)).
The lock screen draws its widgets in its own tint: only shapes and words.

## Next up

| What they have | What the widget shows | A tap opens |
| --- | --- | --- |
| A ticket (registered or confirmed) to an event that isn't over | The soonest one: date block, name, "Today · 9:30 am" / "Tomorrow · 9:30 am" / "In 3 days" / "Happening now"; medium adds the time, the venue (or "Online") and **Show ticket ›** | That ticket (`/events/{id}/ticket`) |
| No ticket, a registration under review | The same, labelled **Under review** (or **Payment due** for a confirmed paid place not paid yet); the club in place of the venue | The event's page |
| Nothing coming up | "Nothing coming up yet" + **Find events** | Discover → Find events |
| Signed out (or the app not opened since install) | "Sign in to see your next event" + **Sign in** | Sign-in, then My events |

**Small** (2×2: the date block, the name and the relative line),
**medium** (4×2: adds the time and the place, and the Show ticket pill) and
**large** (about 4×4: the next three events, soonest first – the first as
the medium widget draws it, with **Show ticket ›** (or **Under review**),
the two after it with a smaller date, when, the name and the place; each
row opens its own ticket, or the event for a registration under review;
with fewer than three, a soft panel in their place says "Nothing else
booked yet" and offers **Find more events ›**). The large one
reads the same stored events as the others (up to four are kept, so three
are left when the first ends); nothing new is stored for it.

**On the iPhone's lock screen** (iOS 16):

| Shape | Shows |
| --- | --- |
| Card (rectangular) | "Next up", the event's name, and "In 2 days" / "Tomorrow · 9:30 am" / "Today · 9:30 am" / "Happening now" |
| Line (inline, above the clock) | "DevFest · in 2 days" / "DevFest · tomorrow" / "DevFest · today 9:30 am" / "DevFest · now" |
| Round (circular) | The day under its month ("NOV / 28"); on the day itself "In 2:15:04", a countdown the system keeps running; "Now" once it started; a ticket with no date |

Signed out: "Sign in to see your next event" (card), "Sign in to
MyOtherApp" (line), a ticket glyph (round). A tap (after unlocking) opens the
ticket, as on the home screen. Only the event's name and time show there:
nothing of the ticket. Android has no lock-screen widgets for phones.

All dates and times are **India time (Asia/Kolkata)**, whatever the phone's
time zone, as on the website.

## Networking

| State | Small (2×2) | Medium (4×2) | A tap opens |
| --- | --- | --- | --- |
| Signed in, code read | The QR code, large enough to scan, the name under it | The code on the left; the name, "Scan to save me", a **Scan** pill and **Network · 12 ›** on the right | The code / the card: **My QR** full screen. Scan: the scanner that saves a person. Network: the Network tab |
| Signed in, no code read yet (the app hasn't opened My QR, or the first run was offline) | A soft placeholder where the code goes, "Tap for your QR" | The placeholder; the name, "Open My QR to get your code", Scan and Network | My QR, which makes the code (`GET /me/qr` makes it on the first ask) |
| Signed out (or the app not opened since install) | "Sign in to share your QR" + **Sign in** | The placeholder; "Sign in to share your QR" + **Sign in** | Sign-in, then My QR |

**Large** (about 4×4): the medium widget on top, then **Recently met** –
the people met last (newest first; four on an iPhone and on a tall Android
widget, three on a shorter one), each a circle with their initials in a
colour of their own from the app's palette (teal, pale yellow, ink, soft
grey; the same person always gets the same one), or their **photo** when
the person turned photos on (below); their name; and the event they met
at. Each opens that person's page in the app (`/network/{id}`), signing in
first. Under them **"3 without a note yet ›"** (only when there are some)
opens the Network tab. Nobody saved yet: a soft panel, "Scan someone's
code to save them. They show here." (it opens the scanner); signed out, the
medium's signed-out face on top and "Sign in to see the people you meet
here." below. On the iPhone it is laid out by the space there is (an iPhone SE's
large widget is 30 points shorter than a Pro Max's): people on one line
each when two won't fit; their names are hidden while the phone is locked
(StandBy), as the code is.

"Without a note" counts the people on the page the app reads – the 50 met
most recently – so it is exact for a network of up to 50, and for a larger
one counts the recent ones, whose notes are the ones still easy to write.

### Photos

Settings → **Show people's photos in widgets** (off by default). Off,
"Recently met" shows initials. On, while a Networking widget is on a home
screen, the app makes a small round photo (96 × 96 px PNG, a few kilobytes)
of each person shown who has a profile picture – from the app's own
picture cache – and keeps it in the widgets' storage. The widgets fall back
to initials for anyone without one, or whose photo can't be read.

The photos are **deleted** when the switch is turned off (at once, and the
widget is drawn again), at **sign-out** (and the switch goes back to off,
so the next person to sign in starts with initials), when a person is no
longer among the four, and when no Networking widget is on a home screen.
A photo is made again only when that person's picture changes.

Sizes and memory: four 96 px photos are about 150 KB once decoded; the iOS
widget decodes each at most 192 px, and Android's RemoteViews carry them
once (well inside its bitmap budget, with the 370 px code).

* The code is **always dark on white with a four-module quiet zone**, in
  the dark theme too, and is drawn by the widget from the stored link (iOS:
  CoreImage's QR generator; Android: ZXing's encoder), error correction M.
  For a profile link (`https://myotherapp.in/p/<10 letters>`) that is a
  29×29-module code.
* **Never on the lock screen.** Android: `widgetCategory="home_screen"`
  only. iOS: home-screen families only (no lock-screen families); the code,
  the name and "Recently met" are `privacySensitive` (hidden while the
  phone is locked, e.g. in StandBy) and the widget is not suggested for
  StandBy (`disfavoredLocations`, iOS 17). On the lock screen the person
  can add **My QR** instead: a button, no code.
* Gallery name and description: **"Networking"** / **"Your QR code to
  share, and quick scan."** Android places it at 2×2; widen it to about 4
  cells for the medium layout, and make it about 4×4 for the large one.
* My QR is the app's `/profile/qr` (`myQrLocation`).

## My QR on the lock screen (iPhone)

A round lock-screen widget (iOS 16.1): the QR glyph and "My QR" on the
lock screen's disc. A tap unlocks the phone and opens **My QR** full
screen (`/profile/qr`). **No code is drawn on the lock screen** – it shows
without unlocking, and a code there is one anyone holding the phone could
scan. It stores and reads nothing. Gallery: **"My QR"** / "Opens your QR
code, full screen."

## Scan and My QR: controls (iPhone) and tiles (Android)

Two buttons for the phone's own quick places, each opening the app on its
page – the same pages, through the same link path, as the icon's shortcuts
and the widgets' taps:

| Button | Opens | iOS symbol |
| --- | --- | --- |
| **Scan** | The scanner that saves a person (`https://myotherapp.in/network/scan`) | `qrcode.viewfinder` |
| **My QR** | My QR, full screen (`https://myotherapp.in/profile/qr`) | `qrcode` |

On a locked phone the phone unlocks first (My QR never shows over the lock
screen); signed out, sign-in comes first and then the page.

**iPhone (iOS 18): controls.** `ScanControl` and `MyQrControl`
(`ios/NextUpWidget/Controls.swift`), in the widget extension's bundle,
gated `@available(iOS 18)`. People add them:

* **Control Center**: swipe down from the top-right corner → touch and hold
  an empty space (or **+**) → **Add a Control** → search "MyOtherApp" →
  **Scan** or **My QR**.
* **Lock screen**: touch and hold the lock screen → **Customize** → **Lock
  Screen** → tap one of the two buttons at the bottom (− to remove the
  torch or camera first) → **MyOtherApp** → Scan or My QR.
* **Action button** (iPhone 15 Pro and later): Settings → **Action Button**
  → swipe to **Controls** → **Choose a Control** → MyOtherApp → Scan or My
  QR.

How a control opens the page: each is a button whose action is an app
intent (`OpenScanIntent`, `OpenMyQrIntent` in `ControlIntents.swift`) with
`openAppWhenRun` (and `requiresAuthentication`). The system opens the app
and runs the intent **in the app's process** – which is why the file is
built into the app target as well as the extension, as Apple asks for an
intent that opens its app. The intent hands the page's address to
`AppLinkHandoff`; `AppDelegate` sets its opener as it finishes launching
and opens the address with `application(_:open:options:)`, Flutter's deep
linking – exactly the path a widget's tap (`widgetURL`) and a quick action
take, so the router reads it as its own page with sign-in first. On a
**cold start** the intent may run before the app has finished launching:
it then leaves the page waiting, and `AppDelegate` opens it once it has.
Not used: `OpenURLIntent` with the https address (iOS opens an address the
website's app-links file doesn't claim – `/network`, `/profile` – in
Safari, not the app) and a custom URL scheme (a second way into the router
for no gain). The intents also show in the Shortcuts app ("Scan someone's
QR", "Show my QR"); nothing else is needed for them.

**Android: Quick Settings tiles.** `ScanTileService` and `MyQrTileService`
(`android/app/src/main/kotlin/app/myotherapp/com/tiles/PageTiles.kt`),
labelled "Scan" and "My QR" with "MyOtherApp" under each (Android 10+),
monochrome icons (the shortcuts' glyphs). The app never asks to add them;
people do it themselves: swipe down twice → the pencil (**Edit**) → drag
**Scan** or **My QR** (MyOtherApp) into the tiles. A tap closes the shade
and opens the page through an intent to `MainActivity` with the address –
the icon shortcuts' intent – as a `PendingIntent` on Android 14 and later
(`startActivityAndCollapse(PendingIntent)`; the `Intent` form throws for an
app that targets 14) and as an `Intent` before; a locked phone unlocks
first (`unlockAndRun`). Each tile is a button, drawn as off.

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
the name (public profile / account) ─┤
the network's size (knownNetwork…)  ─┼─▶ NetworkingWidgetSyncScope ─▶ NetworkingSnapshot ─▶ JSON "networking"
the page last met first (knownRecent…)┤   (main shell)                 + WidgetPhotos ──▶ home_widget/networking_photo_<id>.png
"Show people's photos" (Settings)   ─┤                                                  (only when turned on)
signed in? a widget placed?         ─┘
                                                         │
             home_widget: saveWidgetData(key) / saveFile + updateWidget
               Android: SharedPreferences "HomeWidgetPreferences", files/home_widget/
               iOS:     UserDefaults(suiteName: group.app.myotherapp.in), its container's home_widget/
                                                         │
      Android: NextUpWidgetProvider / NetworkingWidgetProvider (RemoteViews)
      iOS:     NextUpWidget / NetworkingWidget / MyQrLockWidget + the controls
               (WidgetKit, one WidgetBundle)
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
    `isProfileQrLink()`; `networkingLinks` (the taps); `RecentlyMet` /
    `RecentlyMetPerson` ("Recently met", from the network's first page last
    met first); `widgetPhotoKey()`.
  * `data/widget_photos.dart` – `WidgetPhotos` (keeps, matches and deletes
    the photos), `HomeWidgetPhotoStore` (the files through home_widget's
    `saveFile`, and a small index with the Settings switch),
    `CachedWidgetThumbnails` / `roundThumbnail()` (the 96 px round PNG, made
    with `dart:ui` from the private picture cache), `pictureFingerprint()`.
  * `presentation/home_widget_sync.dart`, `networking_widget_sync.dart` –
    the syncs (each writes, and skips a write identical to the last; the
    Networking one writes in order, dropping a write that waited for photos
    when a newer one – a sign-out – came meanwhile) and their scopes in the
    main shell.
  * `presentation/widget_photos_setting.dart` – the Settings switch
    (`widgetPhotosSettingProvider`, `WidgetPhotosRow`).
* **When Next up is written**: app start (once the saved tickets are read);
  resume; a registration; a ticket gone from the server's list (on the next
  refresh of the saved tickets); a registration sent for review or
  withdrawn; sign-in. When a Next up widget is on a home screen the app also
  reads the registrations under review (at most every 10 minutes).
* **When Networking is written**: when My QR reads the code (`GET /me/qr`,
  `myQrProvider`) or replaces it (`POST /me/qr/replace`: the new link at
  once, before My QR reads it back); sign-in and sign-out; when the name
  changes (the public profile, else the account's profile, once read); when
  a page of the whole network (no search or filter) is read; when the first
  page of the network **last met first** is read ("Recently met" and the
  notes still to write: `knownRecentlyMetProvider`); when the photos switch
  changes. Without a Networking widget on a home screen this asks the
  server nothing more than the screens do, and "Recently met" is not
  written at all (nor any photo kept). **With one placed** (and someone
  signed in) the app reads for it, on start and on each return: the code
  (`GET /me/qr`, which makes one on the first ask – the person put their QR
  on their home screen), the account's profile, and the network's first
  page last met first (`GET /network?sort=met&order=desc&page=1&page_size=50`,
  `recentlyMetQuery` – the Network tab's own "Last met" page, so the tab
  sorted that way is the same read): the size, "Recently met" and the notes
  without a note. It is kept current through saves, removals, blocks and
  notes (each reads the network again) and read again at most every 10
  minutes on a return. With photos on, the pictures come from the app's
  private picture cache (already there when the Network tab showed them).
* **Sign-out** (and a session the server ended, and sign-in) writes both
  widgets' signed-out state through `SessionCaches`, deletes the photos and
  turns the photos switch off, with everything else kept about the person.
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
  "met": [                          // "Recently met": absent until read, and
    {                               //   while no Networking widget is placed
      "name": "Ravi Kumar",
      "initials": "RK",
      "colour": 2,                  // 0-3: teal, pale yellow, ink, soft grey
      "event": "DevFest Kochi",     // where they last met at an event; absent if none
      "link": "https://myotherapp.in/network/41",   // their page in the app
      "photo": "networking_photo_41"                // only with photos on, and kept
    }
  ],                                // at most four, last met first
  "no_note": 3,                     // how many of the 50 read have no note yet
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
once when the person replaces their code, and gone at sign-out. For
"Recently met", only each person's display name (as the Network tab shows
it), its initials, a colour number, the event's name and the link to their
page – **never** their handle, headline, company, tags, note (only whether
there is one, counted), picture address, email or phone. Never a ticket or
a token. Signed out, only `v`, `state` and `links`. Tests hold the JSON to
these fields (`test/features/home_widget/networking_widget_test.dart`,
`recently_met_widget_test.dart`).

**Photos** (only with "Show people's photos in widgets" on, and a Networking
widget placed): one PNG per person shown who has a picture,
`home_widget/networking_photo_<id>.png` in the widgets' storage (iOS: the
App Group's container; Android: the app's files), its path under the key
`networking_photo_<id>`, and an index under `networking_photos`:

```json
{"on": true, "saved": {"networking_photo_41": "9f3a61c2"}}
```

– the switch, and for each photo a short fingerprint of the picture it was
made from (a hash of its cache key, so a new picture makes a new photo; not
the picture's address). All deleted at sign-out and when the switch goes
off. Android leaves `home_widget/` out of its backups, as it does the
widgets' preferences.

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
  it writes. The lock screen's widgets use the same timeline; the round
  one's countdown on the day of the event is a system timer
  (`Text(timerInterval:)`), which runs on its own between entries.

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
  `NetworkingData.kt`, `QrBitmap.kt`, `WidgetType.kt`, `WidgetPhotos.kt`),
  `tiles/PageTiles.kt` (the Quick Settings tiles),
  `AppShortcuts.kt` and `MainActivity.kt`,
  `res/layout/widget_{next_up,networking}_{small,medium,large,preview}.xml`,
  `res/xml/{next_up,networking}_widget_info.xml`,
  `res/drawable/widget_*.xml` (with `widget_met_circle_{0-3}.xml`),
  `res/drawable*/ic_shortcut_*.xml`, `res/drawable/ic_tile_{scan,qr}.xml`,
  `res/values{,-night}/widget_{next_up,networking}.xml`,
  `res/values/app_shortcuts.xml` (with the tiles' words), and the
  receivers, the two tile services plus `RECEIVE_BOOT_COMPLETED` in
  `AndroidManifest.xml`. The Kotlin package is
  `app.myotherapp.com` (the namespace), so the Dart side names the
  providers by their full class names. One new dependency:
  `com.google.zxing:core` (the QR encoder; Apache 2.0, plain Java, no
  dependencies; R8 keeps only what is used).
* **iOS**: `ios/NextUpWidget/` – `WidgetBundle.swift` (the `@main` bundle:
  Next up, Networking, My QR on the lock screen from iOS 16.1, the two
  controls from iOS 18), `WidgetStyle.swift` (palette, the circles'
  colours, fonts, pill), `NextUpWidget.swift`, `NextUpData.swift`,
  `NextUpLargeView.swift`, `NextUpLockScreen.swift` (the lock screen's
  views, Next up's and My QR's), `NetworkingWidget.swift`,
  `NetworkingData.swift`, `NetworkingLargeView.swift`, `QRCode.swift`,
  `WidgetPhotoFiles.swift` (reads the kept photos), `MyQrLockWidget.swift`,
  `Controls.swift`, `ControlIntents.swift` (also built into the app),
  `Info.plist`,
  `NextUpWidget.entitlements`, `PrivacyInfo.xcprivacy`,
  `NextUpWidget.xcconfig` – the target in `ios/Runner.xcodeproj`, the App
  Group in `ios/Runner/Runner.entitlements` and `Runner.Release.entitlements`,
  the App Group reason (`1C8F.1`) in `ios/Runner/PrivacyInfo.xcprivacy`, and
  the quick actions in `ios/Runner/Info.plist` + `AppDelegate.swift`.
* The Xcode target is added by **`tool/ios_add_widget_extension.rb`**
  (`ruby tool/ios_add_widget_extension.rb`; it needs the `xcodeproj` gem
  that comes with CocoaPods). It is safe to run again; run it after adding
  a Swift file to `ios/NextUpWidget/` (and add the file to its `SOURCES`;
  a test checks the list against the folder).
  It:
  * raises the app's deployment target from iOS 13.0 to **14.0** (project
    and Podfile) – WidgetKit and the home_widget plugin need iOS 14, and
    every iPhone that ran iOS 13 can run 14;
  * adds the `NextUpWidget` app-extension target: bundle id
    `app.myotherapp.in.NextUpWidget`, Runner's team (`PX6QV826X4`),
    automatic signing, iPhone only, iOS 14.0, version and build number from
    Flutter (`FLUTTER_BUILD_NAME` / `FLUTTER_BUILD_NUMBER`, so they always
    match the app's), its Swift files and the two fonts, and builds the
    controls' intents (`APP_SOURCES`: `ControlIntents.swift`) into Runner
    too;
  * embeds it in Runner ("Embed Foundation Extensions", placed before "Thin
    Binary" – after it Xcode reports a dependency cycle) and makes Runner
    depend on it.

  After it: `flutter pub get && (cd ios && pod install)`.
* Every widget lives in this **one** extension (the target keeps its first
  name, `NextUpWidget`), so new widgets need no new App ID, App Group or
  profile. Newer pieces are gated with `@available` (lock-screen families
  iOS 16, buttons in widgets iOS 17, Controls iOS 18); the bundle checks
  `#available(iOS 16.1, *)` and `#available(iOS 18.0, *)` (16.1 is the
  first a widget bundle can check for). AppIntents is linked weakly (the
  linker does it: every symbol used is newer than iOS 14), so iOS 14 and 15
  still load the extension and the app.

## Owner steps (Apple) – before the next iOS release

**Nothing new for Networking, the large sizes, the lock-screen widgets, the
controls or the shortcuts**: every one is in the same extension, App ID and
App Group as Next up; controls, app intents, lock-screen widgets and quick
actions need no capability or entitlement. The steps below are the ones
Next up already needs; do them once.

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

**Android**: nothing to set up. The widgets, the tiles and the shortcuts
ship in the app.

## Trying it

**iPhone (device or simulator)**

1. `flutter run` (a device needs steps 1–4, or Xcode's automatic signing
   with a team account that may register them).
2. Home screen → touch and hold → **Edit** → **Add Widget** → search
   "MyOtherApp" → **Next up** or **Networking** → pick Small, Medium or
   Large → Add Widget.
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
5. Large: Next up lists the next three, each row opening its ticket.
   Networking lists "Recently met" (save two or three people first, at an
   event for its name to show); a person opens their page; "N without a
   note yet" opens the Network tab; write a note and it counts down.
   Settings → **Show people's photos in widgets** → on: people with a
   profile picture get their photo; off: initials again at once.
6. Lock screen (iOS 16): touch and hold → **Customize** → Lock Screen →
   the widget row (or the line above the clock) → MyOtherApp → Next up
   (card, round) or My QR (round); the line above the clock takes Next up's
   line. Lock the phone: the card says when; on the event's day the round
   one counts down. Tap My QR: Face ID, then My QR full screen.
7. Controls (iOS 18): Control Center → touch and hold → **Add a Control** →
   MyOtherApp → Scan / My QR; also the lock screen's two buttons and
   Settings → Action Button → Controls. With the app closed (swiped away),
   tap one: the app opens on the scanner / My QR (signed out: sign-in
   first).
8. Touch and hold the app's icon: Scan, My QR, Network, My tickets; each
   opens its page (signed out: sign-in first, then the page).
9. Settings → Display & Brightness → Dark: the dark colours (the code stays
   dark on white).
10. Sign out: every widget asks to sign in again; "Recently met" and its
    photos are gone, and the photos switch is off.

**Android**

1. `flutter run` (or install the debug APK).
2. Home screen → touch and hold → **Widgets** → **MyOtherApp** → **Next
   up** (placed at 4×2; resize to 2×2 for the small layout, about 4×4 for
   the large one) or **Networking** (placed at 2×2; widen it to 4 cells for
   the medium one, and make it about 4×4 for the large one – three people,
   four on a taller one).
3. The same checks as above; dark theme from Quick Settings. Shortcuts:
   touch and hold the icon (after the app has been opened once).
4. Tiles: swipe down twice → the pencil (**Edit**) → drag **Scan** and **My
   QR** (MyOtherApp) into the tiles. Tap each with the app closed, and with
   the phone locked (it asks to unlock first): the app opens on the page.
5. To redraw a widget while testing, open the app and leave it again: every
   resume redraws the widgets, and every change the app sees rewrites them.

**Relative line**: register for an event starting in a few minutes; Next up
says "Today · …", and "Happening now" from its start (iOS at the timeline
entry; Android at the booked alarm, which may be a few minutes late), then
moves on to the next event once it ends.

### Previews

`tool/widget_previews/render.sh [out-dir]` draws the iOS widgets' views
(both widgets, every size and state, the large ones also at an iPhone SE's
size, and the lock screen's shapes, light and dark) to PNG on a Mac, with
the app's fonts – a quick look without a phone. Controls are drawn by the
system from their symbol and name, so there is nothing to preview. The
Android layouts are checked on a phone or emulator.
