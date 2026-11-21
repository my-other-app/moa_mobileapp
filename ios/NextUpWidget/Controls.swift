import AppIntents
import SwiftUI
import WidgetKit

// The app's controls (iOS 18): "Scan" and "My QR", for Control Center, the
// lock screen's two buttons and the Action button. Each is a button that
// opens the app on its page (ControlIntents.swift); on a locked phone the
// phone unlocks first, so My QR never shows over the lock screen.
//
// People add them themselves: Control Center → touch and hold → Add a
// Control → MyOtherApp; the lock screen → Customize → a button → the same
// list; Settings → Action Button → Controls (docs/HOME_WIDGETS.md).

@available(iOS 18.0, *)
struct ScanControl: ControlWidget {
  static let kind = "ScanControl"

  var body: some ControlWidgetConfiguration {
    StaticControlConfiguration(kind: ScanControl.kind) {
      ControlWidgetButton(action: OpenScanIntent()) {
        Label("Scan", systemImage: "qrcode.viewfinder")
      }
    }
    .displayName("Scan")
    .description("Scan someone’s code to save them to your network.")
  }
}

@available(iOS 18.0, *)
struct MyQrControl: ControlWidget {
  static let kind = "MyQrControl"

  var body: some ControlWidgetConfiguration {
    StaticControlConfiguration(kind: MyQrControl.kind) {
      ControlWidgetButton(action: OpenMyQrIntent()) {
        Label("My QR", systemImage: "qrcode")
      }
    }
    .displayName("My QR")
    .description("Show your QR code, full screen, for someone to scan.")
  }
}
