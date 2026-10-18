# MyOtherApp 1.1.0 (build 3)

Branch `app/release-1.1.0`. It is `main` with the three Phase 0 branches
merged (`app/p0-core`, `app/p0-events` and `app/p0-platform`), plus the
integration commits that tie them together.

| Check | Result |
| --- | --- |
| `flutter analyze` | no issues |
| `flutter test` | 596 tests, all passing |
| `flutter build apk --release` | builds: 81.6 MB universal APK, versionCode 3 / versionName 1.1.0, debug-signed (no `key.properties` here) |
| iOS | not built here (Xcode is missing the iOS 26.2 platform). `AppDelegate.swift` parses, every plist and `project.pbxproj` lints, and `pod install` ran clean |

---

## 1. Blockers: do these before submitting

Each item below is outside the app, or needs a key the repo doesn't hold.

1. **Merge and deploy backend PR #68** (`feat/app-release-support`, my-other-app/moa_backend#68) with `migrate=true`.
   - It adds the `content_reports` migration, which revises `admin_revenue` and creates two new tables, `content_reports` and `user_blocks`.
   - Prove the alembic chain on a scratch DB first.
   - What the app needs from it:
     - `POST /reports` and `POST/GET/DELETE /user/blocks`. Without them, Report and Block fail, and App Review rejects under guideline 1.2.
     - `DELETE /user/fcm-token`.
     - `is_paid` and `registration_id` on `/events/info`.
     - The error codes: `ALREADY_PAID`, `NOTHING_TO_PAY`, `EVENT_FULL`, `SOLD_OUT`, `REGISTRATIONS_CLOSED`, `PROFILE_EXISTS`, and `ACCOUNT_SUSPENDED` on Google and Apple sign-in.
   - The app degrades without the codes (it matches the old messages), but not without `/reports` and `/user/blocks`.
2. **Website terms** (`moa_eventwebsite/src/content/legal.js`, served at https://myotherapp.in/terms). Guideline 1.2 needs the terms to say:
   - there is **no tolerance for objectionable content or abusive users**;
   - users can report content and block people;
   - reports are acted on within 24 hours, by removing the content and ejecting whoever posted it.

   Today the terms (dated 2025-05-20) say only that reviews must be respectful, and they also say "We do not actively monitor user activity". The app now tells people, before they sign in, that continuing means agreeing to these terms. The site doesn't auto-deploy, so deploy it with the CLI after merging.
3. **Website privacy policy** (https://myotherapp.in/privacy, also dated 2025-05-20). Bring it in line with sections 9 and 10 below:
   - Razorpay payments;
   - Firebase Analytics and Crashlytics;
   - push tokens;
   - Threads comments, reports and blocks;
   - registration details shared with the hosting club;
   - deleting your account in the app (Settings → Delete Account).

   Google Play also wants a **web page that explains how to delete an account**. Give it a dedicated page, or a section anchor the Play form can link to.
4. **support@myotherapp.in has no mailbox.** `myotherapp.in` has no MX record, so mail sent there bounces. That address is used in three places:
   - the app's Contact Support;
   - the suspension message;
   - the privacy policy's deletion-request line.

   Turn on Cloudflare Email Routing (or a real mailbox) for it before release, and use a working inbox as the store contact email.
5. **A way to act on reports.** The backend has `GET /admin/reports` and `POST /admin/reports/{id}/resolve` (dismiss, `remove_content`, `suspend_author`), but the admin app has no screen for them yet. Until it does, someone must check the queue through the API at least daily.
6. **Real `.env` for the store builds.** See section 4.
7. **Keys:**
   - the Android upload keystore and `android/key.properties`;
   - the iOS APNs key in Firebase;
   - the Play and Firebase SHA fingerprints.

   See sections 5 and 6. Also, if the Apple Wallet pass-signing key has not been rotated since it was exposed, rotate it before Wallet is reviewed.

---

## 2. What's in 1.1.0

### Signing in and your session
- The sign-in screen says **"By continuing, you agree to our Terms and Privacy Policy"**, with links to myotherapp.in/terms and /privacy. The email sheet says it too. The screen now scrolls on small phones instead of overflowing.
- The app opens straight away. It no longer shows a blank screen and a notification prompt at launch.
- **Push permission is asked once, after you sign in.** A restored session asks nothing.
- Sign-in failures say what happened in plain words: wrong password, suspended account, club account, two-factor needed. They no longer say "ApiException ... (badRequest, code: 400)".
- A club's email and password are refused cleanly. Before, they left a spinner that never stopped.
- **A new account goes through onboarding details** (name, WhatsApp, college). Before, it skipped straight to home.
- **When the server ends your session** (expired, signed out elsewhere, suspended), the app returns to sign-in and says why, once. Before, it carried on, broken.
- **Sign-out:**
  - asks the server to forget this phone's push token;
  - ends the session on the server;
  - deletes the token on the device;
  - starts the next person with nothing of the last one's: tickets, clubs, the selected tab.

  A phone shared by two accounts no longer gets the other account's pushes.
- The "profile created" screen no longer offers an "add pic" button that did nothing.

### Events and payments
- **Payment due.** An unpaid registration on a paid event no longer shows VIEW TICKET. It shows a **Payment due** badge and **FINISH PAYMENT**, on the Upcoming list and on the event page.
  - FINISH PAYMENT on the list opens the event and starts paying.
  - The list refreshes when you come back.
  - Tapping the card's title or poster opens the page with FINISH PAYMENT waiting.
- Finish payment pays for the existing registration directly. It doesn't re-send the form, and it still works after the registration deadline, until the event ends.
- An already-paid order counts as paid.
- **Refusals say why**, by error code: already registered (with View ticket), payment pending (with Finish payment), registrations closed, event full, item sold out, club email.
- The registration form has **date and time pickers**, **real checkboxes** and radio buttons, and checks required answers first.
- Feeds no longer break on an event whose club is gone, or that has no length ("null Hours" is gone).
- Event share is back, in the app bar and on every card. It links to https://myotherapp.in/events/{slug}.
- Add to Apple Wallet appears **on iOS only**.

### Threads, safety and settings
- **Report** a post or a comment (spam, harassment, hate, sexual, violence, misinformation, other, plus an optional note).
- **Block** the author of a comment. Their comments disappear at once.
- **Settings → Blocked Users** lists who you've blocked, with Unblock.
- Settings → Privacy Policy and Terms open the website. The in-app copies are gone.
- Contact Support writes to support@myotherapp.in instead of a personal WhatsApp number. Settings has a Website row.
- The two notification switches are gone: they changed nothing.

### Clubs
- The club share button works. It links to https://myotherapp.in/clubs/{slug}.
- A club without a logo no longer crashes the clubs tab, and no longer shows a random stock photo as its logo.
- The JOIN THE TEAM button that did nothing is gone.

### Look and feel
- About 100 text styles named fonts that weren't bundled ('DM Sans', 'Bebas Neue', 'Jaro'), so they fell back to the system font. All of them now name the bundled DMSans and BebasNeue, and the bold weights render bold.
- Search handles "C++ & AI".

### Platform
- **Android:**
  - R8 rules (Razorpay, notifications, Crashlytics);
  - the label is "MyOtherApp";
  - a local release build without `key.properties` falls back to the debug key, and CI refuses it;
  - the photo-library permissions an unused code path pulled in are removed.
- **iOS:**
  - **iPhone only**, in portrait;
  - UPI apps can be offered at checkout;
  - the privacy manifest now ships;
  - the display name is "MyOtherApp".
- Six unused packages are dropped: fluttertoast, crypto, webview_flutter, flutter_wallet_card, riverpod_annotation and riverpod_generator.

---

## 3. QA checklist on real devices

**Setup:**
- Run QA on the **Play internal-testing build** and the **TestFlight build**. A local Android build is signed differently, so Google sign-in behaves differently on it.
- Devices: one iPhone, one Android 13+ phone, and an Android 12 or older phone if you have one.
- Backend PR #68 must be deployed.
- Accounts:
  - **A**: Google
  - **B**: Apple
  - **C**: email
  - **D**: a second email account, to be the other person in Threads and the second account on one phone

### Sign-in
- [ ] **Fresh install, iOS and Android.**
  - No notification prompt appears at launch.
  - The sign-in screen shows "By continuing, you agree to our Terms and Privacy Policy".
  - **Terms** opens myotherapp.in/terms in the browser, and **Privacy Policy** opens /privacy.
  - On an iPhone SE-sized screen, the page scrolls and nothing is cut off.
- [ ] **Google** (both platforms). Pick an account, and you land on home (an existing account) or onboarding (a new one).
  - Cancelling the picker shows no error.
  - If sign-in fails on Android with code 10 or "DEVELOPER_ERROR", a SHA fingerprint is missing (section 5).
- [ ] **Apple** (iOS). Face ID, then home or onboarding. Cancelling shows nothing, and "Hide My Email" works.
- [ ] **Email.**
  - A wrong password shows the server's sentence. Nothing says ApiException, DioException or a status code.
  - Create one (new address): the verification code screen, then onboarding.
  - A club account's email is refused with a sentence, and nothing is stored.
- [ ] **New account onboarding.** A brand-new account (try one of each method) goes through each step and lands on home:
  1. profile check;
  2. **details page** (name, WhatsApp optional, college);
  3. avatar;
  4. interests;
  5. "Profile created", where the avatar is not tappable and there's no "add pic".
- [ ] **Push prompt after sign-in.**
  - The system prompt (iOS; Android 13+) appears right after sign-in completes, once.
  - Deny it: the app works.
  - Kill and reopen while signed in: no prompt.
  - Sign out, then sign in again: no second prompt (the system decides).

### Session
- [ ] **Expired session.**
  1. Sign in as C on the phone.
  2. From a laptop, sign in as C (`POST /auth/token`), then call `DELETE /auth/sessions` (signs out every other session).
  3. Use the phone.

  The next time it needs a new access token, it returns to sign-in and says "Your session has ended. Please sign in again." once. No spinner hangs, and you can sign straight back in.
- [ ] **Suspended.** An admin suspends D while D is signed in. The app returns to sign-in with the suspension message, which names support@.
- [ ] **Sign-out with two accounts on one phone (no cross-pushes), on each platform.**
  1. Sign in as A, allow notifications, and follow a club.
  2. Have that club send an announcement. A gets it.
  3. Sign out from Profile or Settings. You land on sign-in, with no flicker through other pages.
  4. Sign in as D on the same phone. Home is the selected tab, and none of A's tickets or clubs show.
  5. Have A's club send another announcement. **The phone receives nothing.**
  6. D follows a club and gets its announcement.

### Events and payments
- [ ] **Finish payment.** This needs `RAZORPAY_KEY_ID` in the build. Use a small-fee test event.
  1. Register for it and close the Razorpay sheet without paying.
  2. Upcoming tab: the card shows the **Payment due** badge and an orange **FINISH PAYMENT** (no separate strip above it).
  3. Tap FINISH PAYMENT: the event page opens and the checkout starts by itself.
  4. Pay: the page shows VIEW TICKET. Go back: the Upcoming card now shows VIEW TICKET.
- [ ] Tapping the **title or poster** of an unpaid card opens the event page with FINISH PAYMENT shown, without starting the checkout.
- [ ] An unpaid registration can still be paid **after the registration deadline**. Once the event has ended, the button reads EVENT ENDED.
- [ ] **Already paid elsewhere.** Pay on the website, then tap FINISH PAYMENT in the app: no charge, and the ticket appears.
- [ ] **An event with required questions:** Finish payment does not show the form again.
- [ ] **Registration error copy.** Each case shows a sentence, never an exception or a status code:

  | Case | What the app shows |
  | --- | --- |
  | Register for an event you're already registered for | "View ticket" offer |
  | Registered on the website without paying, then register in the app | "Finish payment" offer |
  | Full event | "This event is full" |
  | Closed registration | the deadline copy |
  | Sold-out merch | sold-out copy |
  | Club-email-only event | club-email copy |
  | No connection | "No internet connection. Please check your network and try again." |
- [ ] **Registration form.**
  - Date, time and date-time questions open the pickers, and the field reads like "18 Oct 2026, 9:05 AM".
  - Checkbox questions are tick boxes and radio questions are radio buttons.
  - A missing required answer is caught before sending.
- [ ] Feeds (For You, Following, Past, a club's events) draw every card. No "null Hours", and a club-less event shows "Unknown Organizer".

### Threads and safety
- [ ] **Report** (as C, on a club thread where D has commented).
  1. On a post, open the "…" menu and choose Report post, pick a reason, add a note and send. You see "Thanks — our team will review this."
  2. Report D's comment the same way.
  3. Report the same comment again: no error.
  4. In airplane mode, the sheet says so in plain words and stays open.
- [ ] Your **own** comments have delete only. **The club's** replies offer Report only.
- [ ] **Block.** On D's comment, open "…" and choose Block D, then confirm. D's comments disappear immediately, and stay gone after pull-to-refresh and after restarting the app.
- [ ] **Blocked users.** Settings → Blocked Users lists D. Unblock, then refresh the thread: D's comments are back. With nobody blocked, the page shows an empty state.
- [ ] The report shows up on the server (`GET /admin/reports`), and resolving it with `remove_content` hides the comment.

### Sharing, tickets, settings
- [ ] **Share links.** Open each link in a phone browser, and check that a WhatsApp preview shows the title and image.

  | Where | What it shares |
  | --- | --- |
  | Event card share icon | the share sheet with "{name} on MyOtherApp: https://myotherapp.in/events/{slug}" |
  | Event page app bar | the same link |
  | Club page share | https://myotherapp.in/clubs/{slug} |
- [ ] **Wallet on iOS.** Ticket → Add to Apple Wallet: the pass preview appears, and Add puts it in Wallet. **On Android there is no Wallet button.** Share ticket works on both.
- [ ] Add to calendar. On iOS, also tap the event editor's location field.
- [ ] Settings:

  | Row | Expected |
  | --- | --- |
  | Privacy Policy / Terms | opens the website |
  | Website | opens myotherapp.in |
  | Contact Support | opens the mail app addressed to support@myotherapp.in; with no mail app, a "copied" message |
  | Delete Account | deletes the account, then sign-in |
- [ ] Volunteer QR scan: the camera prompt shows its usage text, and a scan checks the ticket in.
- [ ] The clubs tab shows a club with no logo (a neutral placeholder, no crash) and a club without a slug (its share uses the id).

### Look and platform
- [ ] **Fonts render bold.**
  - Headings are BebasNeue (tall condensed capitals): the sign-in screen, the Settings title, Badges, Notifications, the registration form heading.
  - Body text is DMSans, and bold text is visibly bold: event titles, buttons, the "Payment due" badge.
  - Compare the registration form, profile, clubs and Threads against 1.0. None of them should look like Roboto or SF.
- [ ] iPhone: stays in portrait when rotated.
- [ ] iPad, if available: the app runs in the iPhone-sized window.
- [ ] Android: the launcher label is "MyOtherApp", and the notification icon shows (not a white square).
- [ ] Checkout lists the UPI apps installed on the iPhone (GPay, PhonePe, Paytm...).

---

## 4. Building the store binaries

The build bakes `.env` into the binary (envied, obfuscated). Fill in the real values, regenerate, then build. `.env` and `env.g.dart` are gitignored, so never commit them.

```sh
cp .env.example .env
# edit .env:
#   API_BASE_URL=https://api.myotherapp.in/api/v1
#   GOOGLE_CLIENT_ID=<the web client id>
#   ENABLE_ANALYTICS=true
#   RAZORPAY_KEY_ID=<live key id, rzp_live_...>   # without it, Finish payment cannot open the checkout
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # rerun after ANY .env change
flutter analyze && flutter test
```

- **Android:** `flutter build appbundle --release` produces `build/app/outputs/bundle/release/app-release.aab`.
- **iOS:** run `cd ios && pod install && cd ..`, then `flutter build ipa --release`. That produces `build/ios/archive/Runner.xcarchive` and `build/ios/ipa/`.

Delete `build/` afterwards (disk is tight).

---

## 5. Google Play

1. **Upload key**, one time. Keep the keystore out of the repo and backed up.
   ```sh
   keytool -genkeypair -v -keystore ~/keys/myotherapp-upload.jks \
     -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
   Then create `android/key.properties` (gitignored):
   ```properties
   storeFile=/Users/<you>/keys/myotherapp-upload.jks
   storePassword=...
   keyAlias=upload
   keyPassword=...
   ```
   Without that file, a local release build is signed with the debug key, which Play rejects, and a CI build fails on purpose.
2. **Play App Signing.** Let Google manage the app signing key (the default on first upload). `versionCode` 3 must be higher than any build already uploaded.
3. **SHA fingerprints, which Google sign-in needs.**
   1. In Play Console, go to *Test and release → Setup → App signing*.
   2. Copy the SHA-1 and SHA-256 of both the **app signing key** and the **upload key**.
   3. In Firebase, go to *Project settings → Your apps → Android `app.myotherapp.com` → Add fingerprint*, and add all four.
   4. Download `google-services.json` again into `android/app/`, and commit it if it changed.

   The app signs in with the web client as `serverClientId`. The Android OAuth client is matched by package name and SHA-1, so a missing fingerprint fails sign-in with code 10 on Play-installed builds only.
4. **Internal testing.** Upload the AAB to the internal track, install it from Play, and run section 3 on that build.
5. **App content forms:**

   | Form | Answer |
   | --- | --- |
   | Privacy policy | https://myotherapp.in/privacy |
   | App access | some functionality needs sign-in; give the demo account from section 7 |
   | Ads | no ads |
   | Content rating (IARC) | users can interact with each other (Threads comments); no gambling, violence and so on |
   | Target audience | **decide this**. If the audience is college students, choose 18+. Choosing under-18 groups brings in Play's Families and teen policies, and India's DPDP rules for children's data. |
   | Data safety | section 10 |
   | Advertising ID | **Yes, for analytics.** Firebase Analytics adds `com.google.android.gms.permission.AD_ID` to the manifest. To answer No instead, remove that permission with `tools:node="remove"` and add `<meta-data android:name="google_analytics_adid_collection_enabled" android:value="false"/>` |
   | Financial features | none (tickets for real-world events are not a financial service) |
   | Government, health, news | no |
   | Account deletion | in the app (Settings → Delete Account), plus the web page from blocker 3 |
6. **Store listing:**
   - name "MyOtherApp";
   - short description (80 characters at most) and full description (4,000 at most);
   - **512×512 icon** (32-bit PNG);
   - **1024×500 feature graphic** (JPG or 24-bit PNG, no transparency);
   - **at least 2 phone screenshots** (9:16; 1080×1920 or 1080×2400 work);
   - category Events;
   - a contact email with a working inbox (blocker 4).
7. **Production.** Promote the tested build with a staged rollout (for example 20%, then 100%).

Expect these permissions on Play's listing:
- camera (volunteer QR scan);
- notifications;
- NFC and READ_BASIC_PHONE_STATE, merged in from dependencies and never asked for at runtime;
- AD_ID.

Photo and media permissions are removed on purpose.

---

## 6. App Store

1. **Xcode.** Install the iOS 26.2 platform: Xcode → Settings → Components, or `xcodebuild -downloadPlatform iOS`.
2. **Signing.**
   - Settings: Runner target, team `PX6QV826X4`, bundle id `app.myotherapp.com`, automatic signing.
   - Release uses `Runner.Release.entitlements`: `aps-environment = production` and Sign in with Apple.
   - The App ID needs the **Push Notifications** and **Sign in with Apple** capabilities.
3. **APNs key.**
   1. On developer.apple.com, go to *Keys* and add a key with **Apple Push Notifications service**. Download the `.p8`; it downloads once only.
   2. In Firebase, go to *Project settings → Cloud Messaging → Apple app configuration*, and upload the `.p8` with its Key ID and the Team ID.

   Without it, no iPhone gets a push. If a key is already there, check that it hasn't been revoked.
4. **Archive and upload.** Run `flutter build ipa --release` (section 4). Then open `build/ios/archive/Runner.xcarchive` in Xcode's Organizer and choose *Distribute App → App Store Connect → Upload*, or upload the `.ipa` with Transporter.
5. **App Store Connect, version 1.1.0:**
   - **Build:** pick build 3 once it has processed.
   - **Screenshots:** **iPhone 6.9" only**, 1320×2868 or 1290×2796 (portrait). No iPad screenshots: the app is iPhone-only now.
   - **App Privacy:** section 9.
   - **Age rating:** answer **Yes** to user-generated content. Reporting and blocking are in place.
   - **App Review Information:** the demo account and notes from section 7.
   - **Export compliance:** already answered. `ITSAppUsesNonExemptEncryption` is `NO` in Info.plist.
   - **Privacy Policy URL:** https://myotherapp.in/privacy.
   - **Support URL:** a page on myotherapp.in that gives the support email.
   - **Availability (optional):** untick Mac (Apple silicon) and Apple Vision Pro, since the layouts are phone-only.
6. Submit. A phased release is optional.

---

## 7. App Review: demo account and notes

**Set up one demo account before submitting.** Use the same account for both stores.

1. Create it with email sign-in (LOGIN WITH EMAIL → Create one), for example `appreview@myotherapp.in`, with a strong password. Finish email verification and onboarding.
2. Have it follow two or three active clubs.
3. Register it for an **upcoming free event**, so it has a ticket to view.
4. Register it for an **upcoming paid event without paying**, so it shows Payment due and FINISH PAYMENT. Use a club whose checkout is safe to open.
5. Make sure one followed club has a **thread with comments from another account** (D), so Report and Block can be shown.
6. Keep at least one future event open for registration through the review window.
7. Don't block anyone in advance, and don't let anything suspend the account.

**Review notes, ready to paste.** Fill in the credentials.

> MyOtherApp lists events run by college clubs. Students follow clubs,
> register for events, and get a ticket (with a QR code) that the club's
> volunteers scan at the door.
>
> Sign in: tap LOGIN WITH EMAIL and use the demo account below. Google and
> Apple sign-in also work. Creating an account asks the person to agree to
> our Terms (https://myotherapp.in/terms) and Privacy Policy.
>
> User-generated content (guideline 1.2): club posts in Threads can carry
> comments. Every post and every comment by someone else has a "…" menu with
> Report. Comments also offer Block {name}, which hides that person's
> comments at once. Settings → Blocked Users lists blocked people, with
> Unblock. Reports go to our moderation queue and are acted on within 24
> hours. Our terms have no tolerance for objectionable content or abusive
> users.
>
> Payments: paid events sell tickets (and event merchandise) for events that
> take place in person. Payment goes through Razorpay, so in-app purchase
> does not apply (3.1.3(e) and 3.1.5(a)). The demo account has one unpaid
> registration, showing "Payment due" and FINISH PAYMENT. Please don't
> complete a payment.
>
> Notifications: we ask for permission only after sign-in.
> Account deletion: Settings → Delete Account.
> The app is iPhone-only.
>
> Demo account: ____________ / ____________

For Play's *App access* form, give the same credentials, with "Sign in with LOGIN WITH EMAIL".

---

## 8. Version and identifiers

| | Android | iOS |
| --- | --- | --- |
| Version | 1.1.0 (versionCode 3) | 1.1.0 (build 3) |
| ID | `app.myotherapp.com` | `app.myotherapp.com` |
| Minimum OS | API 24 (Android 7.0) | iOS 13.0 |
| Devices | phones | iPhone only (`TARGETED_DEVICE_FAMILY = 1`) |

---

## 9. App Store privacy answers

These answers match `ios/Runner/PrivacyInfo.xcprivacy`:
- **Do you or your partners use data for tracking?** No.
- The app never calls `setUserId` on Analytics or Crashlytics, so usage and diagnostics are not linked to the person.

| Data type | Collected | Linked to the person | Tracking | Purposes | What it is |
| --- | --- | --- | --- | --- | --- |
| Contact Info → Name | Yes | Yes | No | App Functionality | profile name |
| Contact Info → Email Address | Yes | Yes | No | App Functionality | sign-in, tickets |
| Contact Info → Phone Number | Yes | Yes | No | App Functionality | optional WhatsApp number; registration answers |
| Identifiers → User ID | Yes | Yes | No | App Functionality | account id |
| Identifiers → Device ID | Yes | Yes | No | App Functionality, Analytics | push token, Firebase installation id |
| Purchases → Purchase History | Yes | Yes | No | App Functionality | tickets and merchandise bought |
| Financial Info → Payment Info | Yes | Yes | No | App Functionality | entered in Razorpay's in-app checkout; the app never sees card numbers |
| User Content → Other User Content | Yes | Yes | No | App Functionality | Threads comments, reports, registration answers |
| Other Data | Yes | Yes | No | App Functionality | college, interests, chosen avatar, blocks |
| Usage Data → Product Interaction | Yes | No | No | Analytics | Firebase Analytics |
| Diagnostics → Crash Data | Yes | No | No | App Functionality | Crashlytics |
| Diagnostics → Other Diagnostic Data | Yes | No | No | App Functionality, Analytics | Crashlytics and Analytics |

Not collected:
- location;
- contacts;
- photos or videos (avatars are picked from presets);
- health;
- browsing or search history;
- sensitive info.

---

## 10. Google Play Data safety

- **Is all of the user data collected by your app encrypted in transit?** Yes, HTTPS only.
- **Do you provide a way for users to request that their data is deleted?** Yes, in the app (Settings → Delete Account) and by email. Give the deletion web page URL from blocker 3.
- **Shared:** No for every row below.
  - Firebase (Google) and Razorpay process data on the app's behalf, as service providers.
  - Registration details reach the hosting club because the person registered for its event. That is a transfer the person starts and expects, so Play exempts it from "shared".

| Category → type | Collected | Optional? | Purposes |
| --- | --- | --- | --- |
| Personal info → Name | Yes | Required | App functionality, Account management |
| Personal info → Email address | Yes | Required | App functionality, Account management |
| Personal info → User IDs | Yes | Required | App functionality, Account management |
| Personal info → Phone number | Yes | Optional | App functionality |
| Personal info → Other info (college, interests, registration answers) | Yes | Optional | App functionality |
| Financial info → User payment info | Yes (Razorpay checkout in the app) | Optional | App functionality |
| Financial info → Purchase history | Yes | Optional | App functionality |
| Messages / user content → Other in-app messages or content (Threads comments, reports) | Yes | Optional | App functionality |
| App activity → App interactions | Yes | Required | Analytics |
| App info and performance → Crash logs | Yes | Required | App functionality (crash fixing) |
| App info and performance → Diagnostics | Yes | Required | App functionality, Analytics |
| Device or other IDs | Yes (FCM token, Firebase installation id, advertising ID through Firebase Analytics) | Required | App functionality, Analytics |

Not collected:
- location;
- photos and videos;
- audio;
- files and docs (the ticket PDF stays on the phone);
- calendar (Add to calendar writes through the system sheet, and the app reads nothing);
- contacts;
- web browsing;
- health and fitness.

If you remove AD_ID (section 5), drop "advertising ID" from the last row.

---

## 11. Follow-ups that don't block 1.1.0

- An admin screen for the report queue (blocker 5 is the stopgap).
- The add_2_calendar README recommends `NSContactsUsageDescription`, because Apple's event editor offers contact-based location autocomplete. Add it if the calendar QA step shows a problem.
- The event page's "live" link still uses the legacy `/{id}/live`, which the site redirects to `/events/{slug}/live`.
- `UIBackgroundModes` still lists `fetch`, which nothing uses. If review asks about it, remove it.
