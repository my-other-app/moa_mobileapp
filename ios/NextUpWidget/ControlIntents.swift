import AppIntents
import Foundation

// What the controls (Controls.swift) do: open the app on a page. Built
// into both the widget extension (which offers the controls) and the app
// (where the system runs an intent that opens the app), as Apple asks for
// intents that open their app.
//
// The page is opened exactly as a widget's tap or a quick action on the
// icon opens it: the app is handed the website's address
// (`https://myotherapp.in/network/scan`, `/profile/qr`), which Flutter's
// deep linking gives the router, which reads it as its own page -- signing
// in first where the page needs an account (docs/HOME_WIDGETS.md).

/// The pages the controls open.
enum ControlLinks {
  /// The scanner that saves a person.
  static let scan = URL(string: "https://myotherapp.in/network/scan")!
  /// My QR, full screen.
  static let myQr = URL(string: "https://myotherapp.in/profile/qr")!

  /// Only the website's https addresses are ever opened.
  static func isSiteLink(_ url: URL) -> Bool {
    url.scheme == "https" && url.host == "myotherapp.in"
  }
}

/// Hands a page from an intent to the app, in the app's process.
///
/// The app sets [opener] as it finishes launching (AppDelegate). An intent
/// run before that -- a control that launched the app -- leaves its page
/// [waiting], and the app opens it once it is ready.
enum AppLinkHandoff {
  /// Opens a page as a widget's tap does. Set by the app; never in the
  /// widget extension.
  static var opener: ((URL) -> Void)?

  /// A page asked for before the app was ready.
  private(set) static var waiting: URL?

  /// Open [url] in the app, now or once it is ready.
  static func open(_ url: URL) {
    guard ControlLinks.isSiteLink(url) else { return }
    DispatchQueue.main.async {
      if let opener = opener {
        opener(url)
      } else {
        waiting = url
      }
    }
  }

  /// The page left waiting, once: the app opens it as it becomes ready.
  static func takeWaiting() -> URL? {
    defer { waiting = nil }
    return waiting
  }
}

/// "Scan": opens the app on the scanner that saves a person.
@available(iOS 16.0, macOS 13.0, *)
struct OpenScanIntent: AppIntent {
  static let title: LocalizedStringResource = "Scan someone’s QR"
  static let description: IntentDescription? = IntentDescription(
    "Opens MyOtherApp’s scanner, to save someone to your network.")
  static let openAppWhenRun = true
  /// The app opens (and the phone unlocks) first.
  static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

  @MainActor
  func perform() async throws -> some IntentResult {
    AppLinkHandoff.open(ControlLinks.scan)
    return .result()
  }
}

/// "My QR": opens the app on My QR, full screen.
@available(iOS 16.0, macOS 13.0, *)
struct OpenMyQrIntent: AppIntent {
  static let title: LocalizedStringResource = "Show my QR"
  static let description: IntentDescription? = IntentDescription(
    "Opens your MyOtherApp QR code, full screen, for someone to scan.")
  static let openAppWhenRun = true
  /// Never shown on a locked phone: the phone unlocks first.
  static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

  @MainActor
  func perform() async throws -> some IntentResult {
    AppLinkHandoff.open(ControlLinks.myQr)
    return .result()
  }
}
