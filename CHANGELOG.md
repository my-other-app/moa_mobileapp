# Changelog

What changed in the MyOtherApp app for Android and iPhone, written for guests, attendees and the volunteers who check people in at the door.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versions are the store versions, with the build number in brackets.

## [1.4.0] (build 10) - 2026-11-21

Sent to Google Play and the App Store on 21 November 2026. In review.

### Added

- **Quests.** At events that run one, a Quests card on the event page and under your ticket shows your tasks, your points, how far you are from the next milestone and the swag you have unlocked.
- Each quest task has a button that takes you there: scan people's QR codes, play the quiz, answer a poll, give feedback, make your "I'm attending" poster, follow the club or show your ticket. Station tasks tell you which booth to visit.
- Enter the codes shown on stage or around the venue. The app says right away if a code worked, or why not.
- Pick or change your size for a reward, and see where to collect it at the swag desk.
- A quest page lists every task and reward, and shows the leaderboard when the organisers turn it on.
- A push tells you when you unlock a reward and when it is waiting for you at the swag desk. Your quest progress stays readable without signal.
- The Network scanner counts along with a "meet people" task, for example "3 of 5 met".
- **The live room in the event's own look.** The room and the quiz show the organisers' colours, logo, background and fonts.
- New quiz question kinds: true or false, several right answers, type the answer, and put things in order. Poll questions in a quiz carry no points.
- Scores show partial credit, points lost for a wrong answer where the round uses it, double points and streaks.
- Quiz rounds and teams. When a round ends, you move on to the next one without typing the code again.
- The quiz shows when the host pauses, reveals the answer or moves on by countdown.
- More poll kinds: pick several, rate from 1 to 10, rank, and write your own answer. Results show as bars, columns or a donut, and answers can have pictures.
- **Home-screen widgets** in small, medium and large sizes: Next up (your next events, with Show ticket), Networking (your QR code, Scan, and the people you met last) and For you (this week's events in your topics and near you).
- On the day of an event you have a ticket for, a countdown card on your lock screen with your ticket a tap away. On iPhone it is a Live Activity and shows in the Dynamic Island; on Android it is a quiet notification. You can turn it off in Settings.
- Scan and My QR as controls in Control Center, on the lock screen and on the Action button (iPhone with iOS 18), and as Quick Settings tiles on Android.
- Next up and My QR on the iPhone lock screen.
- Touch and hold the app icon for Scan, My QR, Network and My tickets.
- A setting to show people's photos in the widgets. It is off by default.
- Pull down on an event page to refresh it, for example to see a speaker the organisers just added.
- "Show more comments" on posts with many comments.

### Changed

- Loading spinners, pull-to-refresh, menus, pickers, chips and share buttons now look like the rest of the app on every screen.
- Clubs on a profile show their logos.
- Long lists, such as People Like You, a post's comments and the Clubs tab, scroll more smoothly, and tickets and certificates use less memory.

### Fixed

- Share buttons, including "Share my profile link", open the share sheet again on iPad and on iPhones with iOS 26.
- Volunteers can open their events and the door scanner with no signal, once they have opened the list online.
- My Certificates shows all your certificates, not only the most recent ones.
- Following a club from Explore updates the follower count straight away.
- One club with unexpected details no longer breaks a club list.
- Pictures on notifications that arrive while the app is open load faster and no longer pile up on the phone.

### Security

- On iPhone, a fresh install of the app starts signed out, and your session no longer moves to another phone through a backup or transfer. An update keeps you signed in.
- Unsent door scans, saved tickets and certificates, and people saved offline are left out of phone backups.
- Links from clubs, speakers and notifications open only if they are web, email or phone links.
- Your sign-in is sent only to MyOtherApp's own servers.

Behind the scenes: crash reports now count only real crashes.

## [1.3.0] (build 9) - 2026-11-14

On Google Play from 14 November 2026 and on the App Store from 18 November 2026.

### Added

- **Your public profile**: a handle, headline, bio, city, links and projects, with a choice of who sees each part. Preview it as a stranger sees it.
- **My QR**: your personal code, full screen and bright, which works offline once loaded. Others scan it to save you. You can replace the code at any time.
- **Network tab**: everyone you have saved, where you met, your private notes and tags, search and filters, and the people who saved you. Export your network as contact cards or a spreadsheet.
- A Save button in People Like You.
- **Speaker pages** with a photo, bio, links, and upcoming and past talks. Follow a speaker to get a push when they join a new event.
- Agenda sessions show their speakers, and Profile has a Speakers I Follow list.
- **Help and Support** in Settings: answers to common questions, a Contact us form with screenshots, and My requests with the team's replies.
- "Get help with your ticket or payment" on the event page.
- **Share kits** for club team members: ready-made words and posters for Instagram, WhatsApp, LinkedIn, Facebook and X, with one-tap sharing.
- My events now lists registrations that were not confirmed.

### Changed

- The app starts faster. The splash screen no longer waits a fixed time.
- For volunteers: unsent door scans are kept for each account and sent when you are back online. Signing out with unsent scans asks first.

### Fixed

- After a club declines a registration, the event page says so instead of offering Register again.
- The "give your ticket back" link in ticket emails opens the right page on the website.
- After you pay, the app keeps checking until the payment is confirmed, and never asks you to pay twice.
- The registration form accepts email addresses with a "+" or a long ending.
- Going back to the door scanner works again, and one odd event no longer empties a volunteer's list.

### Security

- Ticket codes and other private details are kept out of crash reports and the phone's log.

## [1.2.1] (build 8) - 2026-11-10

On Google Play from 10 November 2026. On the App Store from 17 November 2026: the first release of the new app for iPhone.

### Added

- When a club changes its sign-up questions after you registered, you can add the missing answers from a personal link, from your ticket, or at the door. A "details needed" note shows wherever it applies.

### Changed

- A profile photo is now optional when you sign up. Use "Skip for now" and add one later in Settings.

## [1.2.0] (build 7) - 2026-11-08

On Google Play from 8 November 2026.

### Added

- Registration questions can depend on your earlier answers, so you only see the questions that apply to you.
- Certificates have their own number and a link you can share. Check any certificate by its number, link or QR code.

### Changed

- A new look for the live room, the quiz and the leaderboard: what is happening at a glance, a countdown ring, bigger answer buttons, your score counting up, and a podium for the top three.

### Fixed

- A revoked ticket never shows a QR code, however you open it.
- The app shows a certificate only when the organisers have issued one.
- For volunteers: without signal, the door scanner refuses codes that are not tickets and repeat scans, and marks other tickets "Unverified" so you check the person's name or ID.

## [1.1.0] (build 6) - 2026-10-29

On Google Play from 29 October 2026. The rebuilt app, made through October 2026.

### Added

- Browse events and clubs without signing in: Discover, events near you, topics, a calendar and search.
- Full event pages with the agenda, speakers, organisers, sponsors and partners, the venue map, and events hosted by two clubs together.
- Register and pay in the app, with ticket types, discount codes, merchandise add-ons and waiting lists. On events that review each registration, request a place and follow its status.
- Tickets and certificates that open offline, in the club's own design.
- The live room in the app: quiz, Q&A, polls and the host's updates.
- Club Threads with likes and comments, club pages with the team and partners, and updates from clubs on WhatsApp if you opt in.
- People Like You, a notification inbox, and notifications that open what they point to.
- Email and password accounts with email verification, and changing your avatar and password.
- For volunteers: check people in by ticket code, also offline.

### Changed

- Interests are grouped by topic.
- Event times show in your phone's time zone.

### Fixed

- Problems that stopped some people from registering.

## Earlier (1.0.x and before)

The first versions of the app, for Android: sign in with Google or email, find events and clubs, register, keep your tickets with their QR codes, get push notifications, and check people in at the door as a volunteer.
