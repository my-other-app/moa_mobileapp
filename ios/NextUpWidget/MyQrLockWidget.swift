import SwiftUI
import WidgetKit

/// "My QR" on the lock screen (iOS 16): a round button with the QR glyph
/// that opens My QR full screen (after unlocking). No code is drawn here:
/// the lock screen shows without unlocking, and a code on it would be one
/// anyone holding the phone could scan or photograph.
@available(iOS 16.0, *)
struct MyQrLockWidget: Widget {
  /// The kind (nothing in the app reloads it: it never changes).
  let kind = "MyQrLockWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: MyQrLockProvider()) { _ in
      MyQrLockView()
        .widgetURL(URL(string: NetworkingData.myQrLink)!)
        .accessoryBackground()
    }
    .configurationDisplayName("My QR")
    .description("Opens your QR code, full screen.")
    .supportedFamilies([.accessoryCircular])
  }
}

@available(iOS 16.0, *)
struct MyQrLockProvider: TimelineProvider {
  func placeholder(in context: Context) -> MyQrLockEntry { MyQrLockEntry(date: Date()) }

  func getSnapshot(in context: Context, completion: @escaping (MyQrLockEntry) -> Void) {
    completion(MyQrLockEntry(date: Date()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<MyQrLockEntry>) -> Void) {
    completion(Timeline(entries: [MyQrLockEntry(date: Date())], policy: .never))
  }
}

struct MyQrLockEntry: TimelineEntry {
  let date: Date
}
