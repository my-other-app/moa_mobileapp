import Foundation

/// What the "For you" events widget lists (docs/HOME_WIDGETS.md): one JSON
/// string under `events_for_you` in the App Group's UserDefaults, written
/// by the app (lib/features/home_widget/domain/events_for_you.dart) and,
/// while the app is closed, by the widget itself after it asks the public
/// front page again (ForYouFetch).
///
/// Everything in it is public: the events, the public API's address, the
/// city and its point, the ids of the person's topics. No sign-in token,
/// nothing about a ticket.
struct ForYouData {
  static let dataKey = "events_for_you"

  /// Find events (the website's /events, the app's events directory).
  static let seeAllLink = "https://myotherapp.in/events"

  /// The public API, when the app hasn't said (a widget placed before the
  /// app was opened).
  static let defaultApi = "https://api.myotherapp.in/api/v1"

  /// Asked again this long after the last read (the timeline's refresh).
  static let refreshEvery: TimeInterval = 3 * 3600

  /// How many the medium and the large widget list.
  static let mediumRows = 2
  static let largeRows = 4

  let header: String?
  let items: [ForYouItem]
  let ask: ForYouAsk
  /// When the events were read (epoch ms); 0 for never.
  let fetchedAt: Int64
  /// The front page's ETag, for asking again with If-None-Match.
  let etag: String?

  /// Nothing read yet: the widget asks at once.
  static let unread = ForYouData(
    header: nil, items: [], ask: ForYouAsk(api: defaultApi), fetchedAt: 0, etag: nil)

  /// What the widget gallery shows.
  static func sample(_ now: Date) -> ForYouData {
    func at(_ hours: Double) -> Int64 { Int64((now.timeIntervalSince1970 + hours * 3600) * 1000) }
    return ForYouData(
      header: "For you",
      items: [
        ForYouItem(
          id: 0, name: "An event near you", startsAt: at(30), endsAt: at(33), weekday: "SAT",
          day: "28", month: "NOV", time: "9:30 am", date: "Sat, 28 Nov", club: "A club",
          place: "The venue", link: seeAllLink),
        ForYouItem(
          id: 1, name: "Another this week", startsAt: at(80), endsAt: at(82), weekday: "MON",
          day: "30", month: "NOV", time: "6:00 pm", date: "Mon, 30 Nov", club: "A club",
          place: "Online", link: seeAllLink),
      ], ask: ForYouAsk(api: defaultApi), fetchedAt: 0, etag: nil)
  }

  /// The JSON the app (or the widget) last wrote.
  static func read() -> ForYouData {
    parse(UserDefaults(suiteName: NextUpData.appGroupId)?.string(forKey: dataKey))
  }

  static func parse(_ json: String?) -> ForYouData {
    guard let json = json, let bytes = json.data(using: .utf8),
      let root = (try? JSONSerialization.jsonObject(with: bytes)) as? [String: Any],
      (root["v"] as? Int) == 1
    else { return .unread }
    let items = (root["items"] as? [[String: Any]] ?? []).compactMap(ForYouItem.init(json:))
    return ForYouData(
      header: root["header"] as? String,
      items: items,
      ask: ForYouAsk(json: root["ask"] as? [String: Any] ?? [:]),
      fetchedAt: (root["fetched_at"] as? NSNumber)?.int64Value ?? 0,
      etag: root["etag"] as? String)
  }

  /// Keep this for the widgets (after the widget read the page itself).
  func write() {
    guard let bytes = try? JSONSerialization.data(withJSONObject: json()),
      let text = String(data: bytes, encoding: .utf8)
    else { return }
    UserDefaults(suiteName: NextUpData.appGroupId)?.set(text, forKey: ForYouData.dataKey)
  }

  func json() -> [String: Any] {
    var root: [String: Any] = [
      "v": 1,
      "state": items.isEmpty ? "empty" : "events",
      "items": items.map { $0.json() },
      "see_all": ForYouData.seeAllLink,
      "ask": ask.json(),
      "fetched_at": fetchedAt,
    ]
    if let header = header { root["header"] = header }
    if let etag = etag { root["etag"] = etag }
    return root
  }

  /// The events not over at [now], at most [limit]: the widget's rows.
  func upcoming(at now: Date, limit: Int) -> [ForYouItem] {
    Array(items.filter { !$0.isOver(at: now) }.prefix(limit))
  }

  /// Whether the widget should ask the front page again at [now].
  func isDue(at now: Date) -> Bool {
    fetchedAt <= 0 || Double(IndiaClock.millis(now) - fetchedAt) / 1000 >= ForYouData.refreshEvery
  }

  var seeAllURL: URL { URL(string: ForYouData.seeAllLink)! }
}

struct ForYouItem {
  let id: Int
  let name: String
  /// Epoch milliseconds.
  let startsAt: Int64
  let endsAt: Int64?
  /// In India time, as the app writes them: "SAT", "28", "NOV", "9:30 am",
  /// "Sat, 28 Nov".
  let weekday: String
  let day: String
  let month: String
  let time: String
  let date: String
  let club: String?
  /// The venue, or "Online".
  let place: String?
  /// The event's page: https on the website only.
  let link: String

  init(
    id: Int, name: String, startsAt: Int64, endsAt: Int64?, weekday: String, day: String,
    month: String, time: String, date: String, club: String?, place: String?, link: String
  ) {
    self.id = id
    self.name = name
    self.startsAt = startsAt
    self.endsAt = endsAt
    self.weekday = weekday
    self.day = day
    self.month = month
    self.time = time
    self.date = date
    self.club = club
    self.place = place
    self.link = link
  }

  init?(json: [String: Any]) {
    guard let id = (json["id"] as? NSNumber)?.intValue,
      let name = json["name"] as? String, !name.isEmpty,
      let start = (json["starts_at"] as? NSNumber)?.int64Value,
      let link = json["link"] as? String, ForYouItem.isSiteLink(link)
    else { return nil }
    self.init(
      id: id, name: name, startsAt: start, endsAt: (json["ends_at"] as? NSNumber)?.int64Value,
      weekday: json["weekday"] as? String ?? "", day: json["day"] as? String ?? "",
      month: json["month"] as? String ?? "", time: json["time"] as? String ?? "",
      date: json["date"] as? String ?? "", club: json["club"] as? String,
      place: json["place"] as? String, link: link)
  }

  func json() -> [String: Any] {
    var out: [String: Any] = [
      "id": id, "name": name, "starts_at": startsAt, "weekday": weekday, "day": day,
      "month": month, "time": time, "date": date, "link": link,
    ]
    if let endsAt = endsAt { out["ends_at"] = endsAt }
    if let club = club { out["club"] = club }
    if let place = place { out["place"] = place }
    return out
  }

  func isOver(at now: Date) -> Bool { IndiaClock.millis(now) >= (endsAt ?? startsAt) }

  /// "Kochi Coders · Online".
  var details: String { [club, place].compactMap { $0 }.joined(separator: " · ") }

  var url: URL? { URL(string: link) }

  static func isSiteLink(_ link: String) -> Bool {
    guard let url = URL(string: link) else { return false }
    return url.scheme == "https" && url.host == "myotherapp.in"
  }
}

/// Where the widget asks the front page again: the public API, the city's
/// point, the person's topics (by id).
struct ForYouAsk {
  let api: String
  var topics: [Int] = []
  var city: String? = nil
  var lat: Double? = nil
  var lng: Double? = nil

  init(api: String, topics: [Int] = [], city: String? = nil, lat: Double? = nil, lng: Double? = nil) {
    self.api = api
    self.topics = topics
    self.city = city
    self.lat = lat
    self.lng = lng
  }

  init(json: [String: Any]) {
    let api = json["api"] as? String ?? ""
    self.init(
      api: api.isEmpty ? ForYouData.defaultApi : api,
      topics: (json["topics"] as? [NSNumber] ?? []).map { $0.intValue },
      city: json["city"] as? String,
      lat: (json["lat"] as? NSNumber)?.doubleValue,
      lng: (json["lng"] as? NSNumber)?.doubleValue)
  }

  func json() -> [String: Any] {
    var out: [String: Any] = ["api": api, "topics": topics]
    if let city = city { out["city"] = city }
    if let lat = lat, let lng = lng {
      out["lat"] = lat
      out["lng"] = lng
    }
    return out
  }

  /// `GET {api}/discover/home?lat&lng`: only over https.
  var homeURL: URL? {
    guard var parts = URLComponents(string: api.hasSuffix("/") ? String(api.dropLast()) : api),
      parts.scheme == "https", parts.host != nil
    else { return nil }
    parts.path += "/discover/home"
    if let lat = lat, let lng = lng {
      parts.queryItems = [
        URLQueryItem(name: "lat", value: "\(lat)"), URLQueryItem(name: "lng", value: "\(lng)"),
      ]
    }
    return parts.url
  }
}

/// An event card of the front page, as the widget picks from them.
struct ForYouCard {
  let id: Int
  let name: String
  let ref: String
  let startsAt: Int64
  let endsAt: Int64?
  let club: String?
  let place: String?
  let topics: Set<Int>
  let distanceKm: Double?
  let isOnline: Bool

  /// The server's "near": within 50 km.
  static let nearKm = 50.0
  static let weekMs: Int64 = 7 * 24 * 3600 * 1000
  static let nameLimit = 90

  init?(json: [String: Any]) {
    guard let id = (json["id"] as? NSNumber)?.intValue,
      let startText = json["starts_at"] as? String,
      let start = ForYouCard.millis(iso: startText)
    else { return nil }
    self.id = id
    let rawName = (json["name"] as? String).map(ForYouCard.oneLine) ?? ""
    let named = rawName.isEmpty ? "Untitled event" : rawName
    self.name = String(named.prefix(ForYouCard.nameLimit)).trimmingCharacters(in: .whitespaces)
    let slug = (json["slug"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    self.ref = slug.isEmpty ? "\(id)" : slug
    self.startsAt = start
    self.endsAt = (json["ends_at"] as? String).flatMap(ForYouCard.millis(iso:))
    let online = (json["is_online"] as? Bool) ?? false
    self.isOnline = online
    let venue = (json["location_name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    self.place = online ? "Online" : ((venue?.isEmpty ?? true) ? nil : venue)
    let clubName = ((json["club"] as? [String: Any])?["name"] as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    self.club = (clubName?.isEmpty ?? true) ? nil : clubName
    let topics = (json["topics"] as? [[String: Any]] ?? []).compactMap {
      ($0["id"] as? NSNumber)?.intValue
    }
    self.topics = Set(topics)
    self.distanceKm = (json["distance_km"] as? NSNumber)?.doubleValue
  }

  func isOver(_ now: Int64) -> Bool { now >= (endsAt ?? startsAt) }
  func isThisWeek(_ now: Int64) -> Bool { startsAt < now + ForYouCard.weekMs }
  func isMine(_ topics: [Int]) -> Bool { topics.contains { self.topics.contains($0) } }
  var isNear: Bool { !isOnline && (distanceKm.map { $0 <= ForYouCard.nearKm } ?? false) }

  /// The row the widget shows, in India time.
  var item: ForYouItem {
    let date = Date(timeIntervalSince1970: TimeInterval(startsAt) / 1000)
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_.!~*'()"))
    let path = ref.addingPercentEncoding(withAllowedCharacters: allowed) ?? "\(id)"
    return ForYouItem(
      id: id, name: name, startsAt: startsAt, endsAt: endsAt,
      weekday: ForYouCard.india("EEE", date).uppercased(), day: ForYouCard.india("d", date),
      month: ForYouCard.india("MMM", date).uppercased(), time: ForYouCard.india("h:mm a", date),
      date: ForYouCard.india("EEE, d MMM", date), club: club, place: place,
      link: "https://myotherapp.in/events/\(path)")
  }

  static func oneLine(_ text: String) -> String {
    text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
  }

  /// [date] in India (UTC+05:30 all year), in English: "Sat", "28", "Nov",
  /// "9:30 am".
  static func india(_ format: String, _ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 5 * 3600 + 30 * 60)
    formatter.amSymbol = "am"
    formatter.pmSymbol = "pm"
    formatter.dateFormat = format
    return formatter.string(from: date)
  }

  /// An ISO 8601 time as the server writes it ("2026-11-28T04:00:00+00:00",
  /// with or without fractions of a second), in epoch milliseconds.
  static func millis(iso text: String) -> Int64? {
    let pattern =
      #"^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})(?::(\d{2})(?:\.(\d+))?)?(Z|[+-]\d{2}:?\d{2})?$"#
    guard let regex = try? NSRegularExpression(pattern: pattern),
      let match = regex.firstMatch(
        in: text, range: NSRange(text.startIndex..., in: text))
    else { return nil }
    func group(_ i: Int) -> String? {
      guard let range = Range(match.range(at: i), in: text) else { return nil }
      return String(text[range])
    }
    var parts = DateComponents()
    parts.calendar = Calendar(identifier: .gregorian)
    parts.timeZone = TimeZone(secondsFromGMT: 0)
    parts.year = Int(group(1)!)
    parts.month = Int(group(2)!)
    parts.day = Int(group(3)!)
    parts.hour = Int(group(4)!)
    parts.minute = Int(group(5)!)
    parts.second = Int(group(6) ?? "0")
    guard let base = parts.date else { return nil }
    var ms = Int64((base.timeIntervalSince1970 * 1000).rounded())
    if let fraction = group(7) {
      let digits = (fraction + "000").prefix(3)
      ms += Int64(digits) ?? 0
    }
    if let zone = group(8), zone != "Z" {
      let sign: Int64 = zone.hasPrefix("-") ? -1 : 1
      let numbers = zone.dropFirst().replacingOccurrences(of: ":", with: "")
      let hours = Int64(numbers.prefix(2)) ?? 0
      let minutes = Int64(numbers.suffix(2)) ?? 0
      ms -= sign * (hours * 60 + minutes) * 60 * 1000
    }
    return ms
  }
}

/// The widget's rules for what to list (the same as `pickForYou` in
/// lib/features/home_widget/domain/events_for_you.dart and ForYouData.kt).
enum ForYouPicker {
  static let limit = 6
  static let shown = ForYouData.largeRows

  /// The front page's three lists: `this_week`, `near` (only when the
  /// server placed the visitor) and `popular`.
  static func lists(_ home: [String: Any]) -> (
    thisWeek: [ForYouCard], near: [ForYouCard], popular: [ForYouCard]
  ) {
    func cards(_ key: String) -> [ForYouCard] {
      (home[key] as? [[String: Any]] ?? []).compactMap(ForYouCard.init(json:))
    }
    let where_ = home["where"] as? [String: Any] ?? [:]
    let placed =
      where_["lat"] is NSNumber && where_["lng"] is NSNumber
      && (where_["source"] as? String ?? "none") != "none"
    let near = placed ? cards("near").filter { $0.isNear } : []
    return (cards("this_week"), near, cards("popular"))
  }

  static func pick(
    thisWeek: [ForYouCard], near: [ForYouCard], popular: [ForYouCard], topics: [Int],
    now: Int64
  ) -> (header: String?, items: [ForYouItem]) {
    var seen = Set<Int>()
    var week: [(Int, ForYouCard)] = []
    for card in thisWeek + near where !card.isOver(now) && card.isThisWeek(now) {
      if seen.insert(card.id).inserted { week.append((week.count, card)) }
    }
    week.sort { a, b in
      a.1.startsAt != b.1.startsAt ? a.1.startsAt < b.1.startsAt : a.0 < b.0
    }
    func rank(_ card: ForYouCard) -> Int { card.isMine(topics) ? 0 : (card.isNear ? 1 : 2) }
    let byDate = week.map { $0.1 }
    let weekOrdered = [0, 1, 2].flatMap { r in byDate.filter { rank($0) == r } }
    var more: [ForYouCard] = []
    for card in popular where !card.isOver(now) {
      if seen.insert(card.id).inserted { more.append(card) }
    }
    let popularOrdered = more.filter { $0.isMine(topics) } + more.filter { !$0.isMine(topics) }
    let picked = Array((weekOrdered + popularOrdered).prefix(limit))
    if picked.isEmpty { return (nil, []) }
    return (header(Array(picked.prefix(shown)), topics: topics, now: now), picked.map { $0.item })
  }

  static func header(_ first: [ForYouCard], topics: [Int], now: Int64) -> String {
    if first.contains(where: { $0.isMine(topics) }) { return "For you" }
    if first.contains(where: { $0.isNear && $0.isThisWeek(now) }) { return "This week near you" }
    if first.contains(where: { $0.isThisWeek(now) }) { return "This week" }
    return "Popular"
  }

  /// What [data] becomes once the front page [body] is read at [now].
  static func picked(_ body: Data, for data: ForYouData, now: Date, etag: String?) -> ForYouData? {
    guard let home = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any] else {
      return nil
    }
    let lists = lists(home)
    let nowMs = IndiaClock.millis(now)
    let result = pick(
      thisWeek: lists.thisWeek, near: lists.near, popular: lists.popular,
      topics: data.ask.topics, now: nowMs)
    return ForYouData(
      header: result.header, items: result.items, ask: data.ask, fetchedAt: nowMs, etag: etag)
  }
}

/// The widget asking the front page itself (while the app is closed): a
/// public read, no token, with the last answer's ETag so an unchanged page
/// comes back as a 304 of a few hundred bytes.
enum ForYouFetch {
  private static let queue = DispatchQueue(label: "app.myotherapp.in.foryou")
  private static var waiting: [(ForYouData) -> Void] = []

  /// [data] brought up to date (and kept), or as it was when the page
  /// can't be read. Calls at once share one read.
  static func refresh(_ data: ForYouData, now: Date, completion: @escaping (ForYouData) -> Void) {
    guard let url = data.ask.homeURL else {
      completion(data)
      return
    }
    var first = false
    queue.sync {
      first = waiting.isEmpty
      waiting.append(completion)
    }
    guard first else { return }
    var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    if let etag = data.etag, !data.items.isEmpty {
      request.setValue(etag, forHTTPHeaderField: "If-None-Match")
    }
    URLSession.shared.dataTask(with: request) { body, response, _ in
      let status = (response as? HTTPURLResponse)?.statusCode ?? 0
      let etag = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "ETag")
      var result = data
      if status == 304 {
        result = ForYouData(
          header: data.header, items: data.items, ask: data.ask,
          fetchedAt: IndiaClock.millis(now), etag: data.etag)
        result.write()
      } else if status == 200, let body = body,
        let fresh = ForYouPicker.picked(body, for: data, now: now, etag: etag)
      {
        result = fresh
        result.write()
      }
      var done: [(ForYouData) -> Void] = []
      queue.sync {
        done = waiting
        waiting = []
      }
      done.forEach { $0(result) }
    }.resume()
  }
}
