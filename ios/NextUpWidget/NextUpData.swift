import Foundation

/// What the "Next up" widget shows, as the app wrote it
/// (lib/features/home_widget/domain/next_up.dart, docs/HOME_WIDGETS.md):
/// one JSON string under `next_up` in the App Group's UserDefaults.
///
/// Nothing secret is in it -- no ticket code, no token -- only what the
/// widget shows and the link a tap opens.
struct NextUpData: Decodable {
  /// The App Group the app writes into (home_widget's setAppGroupId).
  static let appGroupId = "group.app.myotherapp.in"
  static let dataKey = "next_up"

  static let signedOutState = "signed_out"
  static let nothingState = "nothing"
  static let upcomingState = "upcoming"

  /// Sign in, then My events (the website's /me/tickets, read by the app).
  static let signInLink = "https://myotherapp.in/me/tickets"
  /// Find events (the website's /events, the app's Discover).
  static let findEventsLink = "https://myotherapp.in/events"

  let v: Int
  let state: String
  let link: String?
  let items: [NextUpItem]

  /// Nothing written yet (the app not opened since install), or a version
  /// this build can't read.
  static let signedOut = NextUpData(v: 1, state: signedOutState, link: signInLink, items: [])

  /// What the widget gallery shows.
  static let sample = NextUpData(
    v: 1, state: upcomingState, link: findEventsLink,
    items: [
      NextUpItem(
        eventId: 0, name: "Your next event",
        startsAt: Int64(Date().addingTimeInterval(26 * 3600).timeIntervalSince1970 * 1000),
        endsAt: nil, weekday: "SAT", day: "28", month: "NOV", time: "9:30 am",
        date: "Sat, 28 Nov", place: "The venue", club: nil, review: false, badge: nil,
        link: findEventsLink)
    ])

  /// The JSON the app last wrote.
  static func read() -> NextUpData {
    guard let defaults = UserDefaults(suiteName: appGroupId),
      let json = defaults.string(forKey: dataKey),
      let bytes = json.data(using: .utf8),
      let data = try? JSONDecoder().decode(NextUpData.self, from: bytes),
      data.v == 1
    else { return .signedOut }
    return data
  }

  /// The event shown at [now]: the first one not over yet.
  func next(at now: Date) -> NextUpItem? {
    guard state == NextUpData.upcomingState else { return nil }
    return items.first { !$0.isOver(at: now) }
  }

  /// What a tap opens when no event is shown.
  var messageLink: URL {
    if state == NextUpData.signedOutState,
      let given = link.flatMap({ URL(string: $0) })
    {
      return given
    }
    return URL(
      string: state == NextUpData.signedOutState
        ? NextUpData.signInLink : NextUpData.findEventsLink)!
  }
}

struct NextUpItem: Decodable {
  let eventId: Int64?
  let name: String
  /// Epoch milliseconds; nil when the club hasn't said.
  let startsAt: Int64?
  let endsAt: Int64?
  /// Formatted in India time by the app: "SAT", "28", "NOV", "9:30 am",
  /// "Sat, 28 Nov".
  let weekday: String?
  let day: String?
  let month: String?
  let time: String?
  let date: String?
  /// The venue or "Online".
  let place: String?
  let club: String?
  /// A registration under review: no ticket yet.
  let review: Bool?
  /// Its pill's words ("Under review").
  let badge: String?
  let link: String

  enum CodingKeys: String, CodingKey {
    case eventId = "event_id"
    case name
    case startsAt = "starts_at"
    case endsAt = "ends_at"
    case weekday, day, month, time, date, place, club, review, badge, link
  }

  var underReview: Bool { review ?? false }

  var url: URL? { URL(string: link) }

  func isOver(at now: Date) -> Bool {
    guard let end = endsAt else { return false }
    return IndiaClock.millis(now) >= end
  }
}

/// India's clock, for the relative line. The same rules as `nextUpWhen` in
/// lib/features/home_widget/domain/next_up.dart (and IndiaClock in
/// NextUpData.kt); Asia/Kolkata is UTC+05:30 all year.
enum IndiaClock {
  static let offsetMs: Int64 = (5 * 60 + 30) * 60 * 1000
  static let dayMs: Int64 = 24 * 60 * 60 * 1000

  static func millis(_ date: Date) -> Int64 {
    Int64((date.timeIntervalSince1970 * 1000).rounded(.down))
  }

  static func date(_ millis: Int64) -> Date {
    Date(timeIntervalSince1970: TimeInterval(millis) / 1000)
  }

  /// The calendar day in India [millis] falls on, as a count of days.
  static func day(of millis: Int64) -> Int64 {
    let shifted = millis + offsetMs
    let quotient = shifted / dayMs
    return shifted % dayMs < 0 ? quotient - 1 : quotient
  }

  /// The next midnight in India after [now].
  static func nextMidnight(after now: Int64) -> Int64 {
    (day(of: now) + 1) * dayMs - offsetMs
  }

  /// "Today · 9:30 am", "Tomorrow · 9:30 am", "In 3 days", "Happening now".
  static func whenLine(_ item: NextUpItem, at now: Date) -> String {
    guard let start = item.startsAt else { return "Date to be announced" }
    let nowMs = millis(now)
    if nowMs >= start { return "Happening now" }
    let days = day(of: start) - day(of: nowMs)
    let time = item.time ?? ""
    switch days {
    case ...0: return time.isEmpty ? "Today" : "Today · \(time)"
    case 1: return time.isEmpty ? "Tomorrow" : "Tomorrow · \(time)"
    default: return "In \(days) days"
    }
  }

  /// The moments after [now] when the widget looks different on its own,
  /// within [days] days: each midnight in India, and each event's start
  /// and end.
  static func changes(_ data: NextUpData, after now: Date, days: Int = 7) -> [Date] {
    let nowMs = millis(now)
    let horizon = nowMs + Int64(days) * dayMs
    var moments = Set<Int64>()
    var midnight = nextMidnight(after: nowMs)
    while midnight <= horizon {
      moments.insert(midnight)
      midnight += dayMs
    }
    if data.state == NextUpData.upcomingState {
      for item in data.items {
        for moment in [item.startsAt, item.endsAt].compactMap({ $0 })
        where moment > nowMs && moment <= horizon {
          moments.insert(moment)
        }
      }
    }
    return moments.sorted().map(date)
  }
}
