import SwiftUI
import WidgetKit

/// The app's widgets and controls, all in this one extension
/// (docs/HOME_WIDGETS.md): one App ID and one App Group for every one.
/// Newer pieces are there only on the iOS that has them: the lock screen's
/// "My QR" from iOS 16 (16.1, the first a widget bundle can check for), the
/// controls from iOS 18.
@main
struct MyOtherAppWidgets: WidgetBundle {
  var body: some Widget {
    NextUpWidget()
    NetworkingWidget()
    if #available(iOS 16.1, *) {
      MyQrLockWidget()
    }
    if #available(iOS 18.0, *) {
      ScanControl()
      MyQrControl()
    }
  }
}
