import SwiftUI
import WidgetKit

/// The app's home-screen widgets, all in this one extension
/// (docs/HOME_WIDGETS.md): one App ID and one App Group for every widget.
@main
struct MyOtherAppWidgets: WidgetBundle {
  var body: some Widget {
    NextUpWidget()
  }
}
