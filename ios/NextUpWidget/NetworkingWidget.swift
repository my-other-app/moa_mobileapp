import SwiftUI
import WidgetKit

/// "Networking", the home-screen widget (docs/HOME_WIDGETS.md): the
/// person's QR code to share, and a quick way to scan someone.
///
/// Small: the code, large enough to scan, with the name under it. Medium:
/// the code on the left; the name, "Scan to save me", a Scan pill and
/// "Network · 12" on the right. The code (and the card) opens My QR full
/// screen, Scan the scanner that saves a person, "Network" the Network tab.
/// Signed out: "Sign in to share your QR". No code read yet: a calm
/// placeholder that opens My QR, which makes it.
///
/// The code is made here from the link the app wrote (QRCode), dark on
/// white with its quiet zone in both themes, and is hidden when the phone is
/// locked (StandBy).
struct NetworkingWidget: Widget {
  /// The kind the app reloads (NetworkingKind.iOSKind in Dart).
  let kind = "NetworkingWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: NetworkingProvider()) { entry in
      NetworkingView(entry: entry)
    }
    .configurationDisplayName("Networking")
    .description("Your QR code to share, and quick scan.")
    .supportedFamilies([.systemSmall, .systemMedium])
    .notSuggestedInStandBy()
  }
}

extension WidgetConfiguration {
  /// A code on a phone's nightstand screen is one anyone in the room could
  /// scan: StandBy doesn't suggest this widget (and the code is hidden while
  /// the phone is locked anyway, `privateWhenLocked`).
  func notSuggestedInStandBy() -> some WidgetConfiguration {
    #if os(iOS)
      if #available(iOSApplicationExtension 17.0, *) {
        return disfavoredLocations([.standBy], for: [.systemSmall])
      } else {
        return self
      }
    #else
      return self
    #endif
  }
}

struct NetworkingEntry: TimelineEntry {
  let date: Date
  let data: NetworkingData
}

struct NetworkingProvider: TimelineProvider {
  func placeholder(in context: Context) -> NetworkingEntry {
    NetworkingEntry(date: Date(), data: .sample)
  }

  func getSnapshot(in context: Context, completion: @escaping (NetworkingEntry) -> Void) {
    let data = NetworkingData.read()
    // The gallery shows an example code rather than "Sign in".
    let shown = context.isPreview && data.qrPayload == nil ? NetworkingData.sample : data
    completion(NetworkingEntry(date: Date(), data: shown))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<NetworkingEntry>) -> Void) {
    // Nothing here changes with the clock: the app reloads the timeline
    // whenever it writes.
    completion(Timeline(entries: [NetworkingEntry(date: Date(), data: .read())], policy: .never))
  }
}

// MARK: - Views

struct NetworkingView: View {
  let entry: NetworkingEntry

  @Environment(\.widgetFamily) private var family
  @Environment(\.colorScheme) private var scheme

  var body: some View {
    let palette = WidgetPalette.of(scheme)
    NetworkingContent(data: entry.data, medium: family == .systemMedium, palette: palette)
      .widgetURL(entry.data.qrURL)
      .widgetBackground(palette.background)
  }
}

/// What the widget shows, for a size: apart from the environment so the
/// previews can draw each size and theme.
struct NetworkingContent: View {
  let data: NetworkingData
  let medium: Bool
  let palette: WidgetPalette

  var body: some View {
    if !data.signedIn {
      NetworkingSignedOut(medium: medium, palette: palette)
    } else if medium {
      NetworkingMedium(data: data, palette: palette)
    } else {
      NetworkingSmall(data: data, palette: palette)
    }
  }
}

/// The code on its white tile -- or, with no code yet, a soft placeholder.
struct QRTile: View {
  let payload: String?
  let palette: WidgetPalette

  var body: some View {
    Group {
      if let payload = payload, let image = QRCode.image(for: payload) {
        Image(decorative: image, scale: 1)
          .resizable()
          .interpolation(.none)
          .aspectRatio(1, contentMode: .fit)
          .background(Color.white)
          .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
          .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
              .stroke(palette.tileOutline, lineWidth: 1)
          )
          .accessibilityElement()
          .accessibilityLabel("Your QR code")
          .privateWhenLocked()
      } else {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .fill(palette.soft)
          .aspectRatio(1, contentMode: .fit)
          .overlay(
            Image(systemName: "qrcode")
              .font(.system(size: 30, weight: .regular))
              .foregroundColor(palette.secondary)
          )
          .accessibilityElement()
          .accessibilityLabel("Open My QR")
      }
    }
  }
}

struct NetworkingSmall: View {
  let data: NetworkingData
  let palette: WidgetPalette

  var body: some View {
    VStack(spacing: 6) {
      QRTile(payload: data.qrPayload, palette: palette)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      Text(data.qrPayload == nil ? "Tap for your QR" : (data.shownName ?? "My QR"))
        .font(WidgetFonts.text(12, .semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .foregroundColor(data.qrPayload == nil ? palette.secondary : palette.ink)
        .privateWhenLocked()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

struct NetworkingMedium: View {
  let data: NetworkingData
  let palette: WidgetPalette

  var body: some View {
    HStack(alignment: .center, spacing: 14) {
      QRTile(payload: data.qrPayload, palette: palette)
      VStack(alignment: .leading, spacing: 2) {
        Text(data.shownName ?? "My QR")
          .font(WidgetFonts.text(16, .semibold))
          .lineLimit(2)
          .foregroundColor(palette.ink)
          .privateWhenLocked()
        Text(data.qrPayload == nil ? "Open My QR to get your code" : "Scan to save me")
          .font(WidgetFonts.text(12))
          .lineLimit(2)
          .foregroundColor(palette.secondary)
        Spacer(minLength: 6)
        WidgetLink(destination: data.scanURL) {
          Pill(
            text: "Scan", fill: palette.pillFill, ink: palette.pillInk,
            outline: palette.pillOutline, symbol: "qrcode.viewfinder")
        }
        WidgetLink(destination: data.networkURL) {
          Text(data.networkLine)
            .font(WidgetFonts.text(12, .semibold))
            .lineLimit(1)
            .foregroundColor(palette.accent)
            .padding(.top, 6)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
  }
}

/// "Sign in to share your QR".
struct NetworkingSignedOut: View {
  let medium: Bool
  let palette: WidgetPalette

  var body: some View {
    HStack(spacing: 14) {
      if medium {
        QRTile(payload: nil, palette: palette)
      }
      VStack(alignment: .leading, spacing: 4) {
        Text("MyOtherApp")
          .font(WidgetFonts.text(10, .semibold))
          .textCase(.uppercase)
          .foregroundColor(palette.accent)
        Text("Sign in to share your QR")
          .font(WidgetFonts.text(medium ? 17 : 15, .semibold))
          .lineLimit(3)
          .foregroundColor(palette.ink)
        Spacer(minLength: 6)
        Pill(
          text: "Sign in", fill: palette.pillFill, ink: palette.pillInk,
          outline: palette.pillOutline)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }
}

/// A part of a medium widget that opens its own page (iOS 14's `Link`);
/// the rest of the widget opens `widgetURL`. Drawn without the link off the
/// phone (the Mac previews).
struct WidgetLink<Content: View>: View {
  let destination: URL
  @ViewBuilder let content: () -> Content

  var body: some View {
    #if os(iOS)
      Link(destination: destination, label: content)
    #else
      content()
    #endif
  }
}

extension View {
  /// Hidden (redacted) while the phone is locked, as in StandBy.
  @ViewBuilder
  func privateWhenLocked() -> some View {
    if #available(iOSApplicationExtension 15.0, macOS 12.0, *) {
      privacySensitive()
    } else {
      self
    }
  }
}
