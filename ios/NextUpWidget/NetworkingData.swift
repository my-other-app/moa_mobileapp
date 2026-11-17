import Foundation

/// What the "Networking" widget shows, as the app wrote it
/// (lib/features/home_widget/domain/networking.dart, docs/HOME_WIDGETS.md):
/// one JSON string under `networking` in the App Group's UserDefaults.
///
/// Only what the widget shows and where a tap goes: the person's name, the
/// public profile link their QR encodes, the size of their network, and the
/// taps' links. Never a ticket, a token, an email or a phone number.
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

  let v: Int
  let state: String
  let name: String?
  let profileLink: String?
  let network: Int?
  let links: Links?

  enum CodingKeys: String, CodingKey {
    case v, state, name
    case profileLink = "profile_link"
    case network, links
  }

  /// Nothing written yet (the app not opened since install), or a version
  /// this build can't read.
  static let signedOut = NetworkingData(
    v: 1, state: signedOutState, name: nil, profileLink: nil, network: nil, links: nil)

  /// What the widget gallery shows: an example code, not anyone's.
  static let sample = NetworkingData(
    v: 1, state: readyState, name: "Your name", profileLink: "https://myotherapp.in",
    network: 12, links: nil)

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
