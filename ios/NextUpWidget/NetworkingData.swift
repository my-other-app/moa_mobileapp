import Foundation

/// What the "Networking" widget shows, as the app wrote it
/// (lib/features/home_widget/domain/networking.dart, docs/HOME_WIDGETS.md):
/// one JSON string under `networking` in the App Group's UserDefaults.
///
/// Only what the widget shows and where a tap goes: the person's name, the
/// public profile link their QR encodes, the size of their network, the
/// taps' links, and for the large widget's "Recently met" a few people's
/// names, initials, circle colours, where they met, the key of each one's
/// photo (only when the person turned photos on) and how many have no note
/// yet. Never a ticket, a token, an email or a phone number.
struct NetworkingData: Decodable {
  static let dataKey = "networking"

  static let signedOutState = "signed_out"
  static let noQrState = "no_qr"
  static let readyState = "ready"

  /// My QR, full screen (signing in first when needed).
  static let myQrLink = "https://myotherapp.in/profile/qr"
  /// The scanner that saves a person.
  static let scanLink = "https://myotherapp.in/network/scan"
  /// The Network tab.
  static let networkLink = "https://myotherapp.in/network"

  struct Links: Decodable {
    let qr: String?
    let scan: String?
    let network: String?
  }

  /// Someone on "Recently met".
  struct Met: Decodable, Equatable {
    let name: String
    let initials: String?
    /// One of the circles' colours (WidgetPalette.circle), from the app.
    let colour: Int?
    /// The event they last met at.
    let event: String?
    /// Their page in the app: `https://myotherapp.in/network/{id}`.
    let link: String?
    /// The key the app kept their photo under; none unless photos are on.
    let photo: String?

    /// The letters in their circle: as the app wrote them, else made here.
    var shownInitials: String {
      if let given = initials?.trimmingCharacters(in: .whitespaces), !given.isEmpty {
        return String(given.prefix(2))
      }
      return NetworkingData.initials(of: name)
    }

    var url: URL { NetworkingData.siteURL(link, or: NetworkingData.networkLink) }
  }

  let v: Int
  let state: String
  let name: String?
  let profileLink: String?
  let network: Int?
  /// "Recently met", last met first; nil until the app has read it.
  let met: [Met]?
  /// How many of the people the app read have no note yet.
  let noNote: Int?
  let links: Links?

  enum CodingKeys: String, CodingKey {
    case v, state, name
    case profileLink = "profile_link"
    case network, met
    case noNote = "no_note"
    case links
  }

  init(
    v: Int, state: String, name: String?, profileLink: String?, network: Int?,
    met: [Met]? = nil, noNote: Int? = nil, links: Links?
  ) {
    self.v = v
    self.state = state
    self.name = name
    self.profileLink = profileLink
    self.network = network
    self.met = met
    self.noNote = noNote
    self.links = links
  }

  /// Nothing written yet (the app not opened since install), or a version
  /// this build can't read.
  static let signedOut = NetworkingData(
    v: 1, state: signedOutState, name: nil, profileLink: nil, network: nil, links: nil)

  /// What the widget gallery shows: an example code, not anyone's, and
  /// made-up people.
  static let sample = NetworkingData(
    v: 1, state: readyState, name: "Your name", profileLink: "https://myotherapp.in",
    network: 12,
    met: [
      Met(name: "Ravi Kumar", initials: "RK", colour: 0, event: "DevFest", link: nil, photo: nil),
      Met(name: "Meera Das", initials: "MD", colour: 1, event: "DevFest", link: nil, photo: nil),
      Met(name: "Arjun Nair", initials: "AN", colour: 2, event: "Hack Night", link: nil, photo: nil),
    ],
    noNote: 2, links: nil)

  /// The JSON the app last wrote.
  static func read() -> NetworkingData {
    guard let defaults = UserDefaults(suiteName: NextUpData.appGroupId),
      let json = defaults.string(forKey: dataKey)
    else { return .signedOut }
    return parse(json)
  }

  static func parse(_ json: String) -> NetworkingData {
    guard let bytes = json.data(using: .utf8),
      let data = try? JSONDecoder().decode(NetworkingData.self, from: bytes),
      data.v == 1
    else { return .signedOut }
    return data
  }

  var signedIn: Bool { state != NetworkingData.signedOutState }

  /// What the QR encodes, when there is a code to draw: only the website's
  /// https links.
  var qrPayload: String? {
    guard state == NetworkingData.readyState,
      let link = profileLink, let url = URL(string: link),
      url.scheme == "https", url.host == "myotherapp.in"
    else { return nil }
    return link
  }

  /// The person's name, when known.
  var shownName: String? {
    guard let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty
    else { return nil }
    return name
  }

  /// The people "Recently met" shows: the first [limit].
  func recentlyMet(limit: Int = 4) -> [Met] {
    Array((met ?? []).prefix(limit))
  }

  /// "3 without a note yet ›", or nil when every one has a note.
  var noNoteLine: String? {
    guard let count = noNote, count > 0 else { return nil }
    return "\(count) without a note yet ›"
  }

  /// "Ananya Iyer" -> "AI"; "?" for no name (initialsOf in the app).
  static func initials(of name: String) -> String {
    let words = name.split(whereSeparator: { $0.isWhitespace })
    guard let first = words.first?.first else { return "?" }
    let last = words.count > 1 ? words.last?.first : nil
    return (String(first) + (last.map { String($0) } ?? "")).uppercased()
  }

  /// "Network · 12", or "Network" before the size is known.
  var networkLine: String {
    guard let count = network, count >= 0 else { return "Network ›" }
    return "Network · \(count) ›"
  }

  var qrURL: URL { NetworkingData.siteURL(links?.qr, or: NetworkingData.myQrLink) }
  var scanURL: URL { NetworkingData.siteURL(links?.scan, or: NetworkingData.scanLink) }
  var networkURL: URL { NetworkingData.siteURL(links?.network, or: NetworkingData.networkLink) }

  /// [given] when it is one of the website's https addresses, else [fallback].
  static func siteURL(_ given: String?, or fallback: String) -> URL {
    if let given = given, let url = URL(string: given), url.scheme == "https",
      url.host == "myotherapp.in"
    {
      return url
    }
    return URL(string: fallback)!
  }
}
