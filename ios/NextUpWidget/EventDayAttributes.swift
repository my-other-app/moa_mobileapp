import Foundation

#if os(iOS) && canImport(ActivityKit)
  import ActivityKit
#endif

// The event-day card (docs/HOME_WIDGETS.md, "Event-day card"): a Live
// Activity on the day of an event the person holds a ticket for -- the
// event's name, a countdown to its start that the system runs by itself,
// the venue and "Show ticket"; from the start, that it is on; after the
// end, gone. Built into both the app (which starts, updates and ends it:
// ios/Runner/EventDayActivities.swift) and the widget extension (which
// draws it: EventDayLiveActivity.swift). Local only: no push.
//
// It is drawn on the lock screen, so it holds only what it shows and where
// a tap goes: never the ticket's code, its QR or its link -- "Show ticket"
// opens the ticket's page in the app (`/events/{id}/ticket`), which finds
// the code on the phone.

#if os(iOS) && canImport(ActivityKit)
  @available(iOS 16.1, *)
  struct EventDayAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
      var name: String
      /// The venue, "Online", or nil.
      var place: String?
      var startsAt: Date
      var endsAt: Date
      /// "9:30 am", in India.
      var time: String
      /// The app has seen the start pass (else the stale date says so).
      var started: Bool
    }

    /// The event.
    var eventId: Int
    /// "Show ticket": `https://myotherapp.in/events/{id}/ticket`.
    var link: String
  }
#endif

/// Where the card stands.
enum EventDayPhase: Equatable {
  /// Before the start: the countdown.
  case soon
  /// Between the start and the end: "Happening now".
  case now
  /// After the end: the card goes.
  case over
}

/// The card's clock: pure, so the rules can be checked off the phone.
enum EventDayClock {
  /// A card ended once the event is on stays on the lock screen at most
  /// this long (the system's limit for an ended Live Activity).
  static let lingerLimit: TimeInterval = 4 * 3600

  static func phase(startsAt: Date, endsAt: Date, now: Date) -> EventDayPhase {
    if now >= endsAt { return .over }
    return now >= startsAt ? .now : .soon
  }

  /// When the card's face changes by itself (iOS 16.2's stale date): the
  /// start, before it; the end, during the event.
  static func staleDate(startsAt: Date, endsAt: Date, now: Date) -> Date? {
    switch phase(startsAt: startsAt, endsAt: endsAt, now: now) {
    case .soon: return startsAt
    case .now: return endsAt
    case .over: return nil
    }
  }

  /// During the event, with its end near enough that the system keeps an
  /// ended card that long: the card is ended now and kept on the lock
  /// screen until the end, when the system takes it away by itself.
  static func endsByItself(startsAt: Date, endsAt: Date, now: Date) -> Bool {
    phase(startsAt: startsAt, endsAt: endsAt, now: now) == .now
      && endsAt.timeIntervalSince(now) <= lingerLimit
  }

  /// Only the website's https addresses are opened.
  static func isSiteLink(_ link: String) -> Bool {
    guard let url = URL(string: link) else { return false }
    return url.scheme == "https" && url.host == "myotherapp.in"
  }
}

/// What the card shows, apart from ActivityKit (so the views draw on a Mac
/// for the previews).
struct EventDayFace {
  let name: String
  let place: String?
  let startsAt: Date
  let endsAt: Date
  let time: String
  let link: URL?
  /// Where it stands as drawn: from the app's word and the stale date.
  let phase: EventDayPhase

  /// "Until 5:30 pm".
  var untilLine: String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 5 * 3600 + 30 * 60)
    formatter.amSymbol = "am"
    formatter.pmSymbol = "pm"
    formatter.dateFormat = "h:mm a"
    return "Until \(formatter.string(from: endsAt))"
  }
}
