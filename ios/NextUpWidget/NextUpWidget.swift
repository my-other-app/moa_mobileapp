import SwiftUI
import WidgetKit

/// "Next up", the home-screen widget (docs/HOME_WIDGETS.md): the next
/// event the person holds a ticket for, or a registration under review;
/// "Find events" with nothing coming up; "Sign in to see your next event"
/// signed out.
///
/// The app writes what to show into the App Group (NextUpData); this lays
/// it out, small (the date and the name) or medium (adds the time, the
/// place and "Show ticket"), and works out the line that depends on the
/// clock on India's clock. The timeline has an entry for each moment that
/// line changes -- every midnight in India, each event's start and end --
/// and the app reloads it whenever what it shows changes.
///
/// A tap opens the website's address for the event's ticket
/// (`/events/{id}/ticket`), which the app reads as its own page (Flutter
/// deep linking): the ticket's code is never here.
@main
struct NextUpWidgetBundle: WidgetBundle {
  var body: some Widget {
    NextUpWidget()
  }
}

struct NextUpWidget: Widget {
  /// The kind the app reloads (HomeWidgetNextUpStore.iOSKind).
  let kind = "NextUpWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: NextUpProvider()) { entry in
      NextUpView(entry: entry)
    }
    .configurationDisplayName("Next up")
    .description("Your next event: its date, time and place. Tap to open your ticket.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

struct NextUpEntry: TimelineEntry {
  let date: Date
  let data: NextUpData
}

struct NextUpProvider: TimelineProvider {
  func placeholder(in context: Context) -> NextUpEntry {
    NextUpEntry(date: Date(), data: .sample)
  }

  func getSnapshot(in context: Context, completion: @escaping (NextUpEntry) -> Void) {
    let data = NextUpData.read()
    // The gallery shows an example rather than "Sign in".
    let shown: NextUpData =
      context.isPreview && data.next(at: Date()) == nil ? NextUpData.sample : data
    completion(NextUpEntry(date: Date(), data: shown))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<NextUpEntry>) -> Void) {
    let now = Date()
    let data = NextUpData.read()
    let moments = [now] + IndiaClock.changes(data, after: now)
    let entries = moments.map { NextUpEntry(date: $0, data: data) }
    // Asked again after the last entry (a week on at most); the app
    // reloads it sooner whenever what it shows changes.
    completion(Timeline(entries: entries, policy: .atEnd))
  }
}

// MARK: - Colours

/// The app's colours: ink #2C333D, the tabs' pale yellow #F9FFA1, the
/// icon's teal #17A58F. Dark: the ink as the ground, the yellow as accent.
struct NextUpPalette {
  let background: Color
  let ink: Color
  let secondary: Color
  let accent: Color
  let dateFill: Color
  let dateInk: Color
  let pillFill: Color
  let pillInk: Color
  let pillOutline: Color
  let reviewFill: Color
  let reviewInk: Color

  static func of(_ scheme: ColorScheme) -> NextUpPalette {
    scheme == .dark
      ? NextUpPalette(
        background: Color(hex: 0x2C333D), ink: .white, secondary: Color(hex: 0xB9C0C9),
        accent: Color(hex: 0xF9FFA1), dateFill: Color(hex: 0x17A58F), dateInk: .white,
        pillFill: Color(hex: 0xF9FFA1), pillInk: Color(hex: 0x2C333D),
        pillOutline: Color(hex: 0xF9FFA1), reviewFill: Color(hex: 0x3B4350),
        reviewInk: Color(hex: 0xF9FFA1))
      : NextUpPalette(
        background: .white, ink: Color(hex: 0x2C333D), secondary: Color(hex: 0x5F6773),
        accent: Color(hex: 0x127F6E), dateFill: Color(hex: 0x17A58F), dateInk: .white,
        pillFill: Color(hex: 0xF9FFA1), pillInk: Color(hex: 0x2C333D),
        pillOutline: Color(hex: 0x2C333D), reviewFill: Color(hex: 0xF3F3F3),
        reviewInk: Color(hex: 0x2C333D))
  }
}

extension Color {
  init(hex: UInt32) {
    self.init(
      red: Double((hex >> 16) & 0xFF) / 255,
      green: Double((hex >> 8) & 0xFF) / 255,
      blue: Double(hex & 0xFF) / 255)
  }
}

// MARK: - Views

struct NextUpView: View {
  let entry: NextUpEntry

  @Environment(\.widgetFamily) private var family
  @Environment(\.colorScheme) private var scheme

  var body: some View {
    let palette = NextUpPalette.of(scheme)
    let item = entry.data.next(at: entry.date)
    Group {
      if let item = item {
        if family == .systemMedium {
          MediumEventView(item: item, now: entry.date, palette: palette)
        } else {
          SmallEventView(item: item, now: entry.date, palette: palette)
        }
      } else {
        MessageView(
          signedOut: entry.data.state == NextUpData.signedOutState,
          medium: family == .systemMedium, palette: palette)
      }
    }
    .widgetURL(item?.url ?? entry.data.messageLink)
    .nextUpBackground(palette.background)
  }
}

/// The date block: weekday, day, month.
struct DateBlock: View {
  let item: NextUpItem
  let large: Bool
  let palette: NextUpPalette

  var body: some View {
    VStack(spacing: 0) {
      Text(item.day == nil ? "" : (item.weekday ?? ""))
        .font(.system(size: large ? 10 : 9, weight: .semibold))
      Text(item.day ?? "—")
        .font(.system(size: large ? 26 : 20, weight: .bold, design: .rounded))
        .minimumScaleFactor(0.6)
      Text(item.day == nil ? "TBA" : (item.month ?? ""))
        .font(.system(size: large ? 10 : 9, weight: .semibold))
    }
    .lineLimit(1)
    .foregroundColor(palette.dateInk)
    .frame(minWidth: large ? 52 : 42)
    .padding(.horizontal, large ? 6 : 4)
    .padding(.vertical, large ? 6 : 4)
    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(palette.dateFill))
  }
}

struct SmallEventView: View {
  let item: NextUpItem
  let now: Date
  let palette: NextUpPalette

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(alignment: .top, spacing: 6) {
        DateBlock(item: item, large: false, palette: palette)
        Spacer(minLength: 0)
        Text(item.underReview ? (item.badge ?? "Under review") : "Next up")
          .font(.system(size: 10, weight: .semibold))
          .textCase(.uppercase)
          .multilineTextAlignment(.trailing)
          .lineLimit(2)
          .foregroundColor(palette.accent)
      }
      Spacer(minLength: 6)
      Text(item.name)
        .font(.system(size: 15, weight: .semibold))
        .lineLimit(2)
        .foregroundColor(palette.ink)
      Text(IndiaClock.whenLine(item, at: now))
        .font(.system(size: 12))
        .lineLimit(1)
        .foregroundColor(palette.secondary)
        .padding(.top, 2)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }
}

struct MediumEventView: View {
  let item: NextUpItem
  let now: Date
  let palette: NextUpPalette

  private var details: String {
    [item.time, item.place ?? item.club].compactMap { $0 }.joined(separator: " · ")
  }

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      DateBlock(item: item, large: true, palette: palette)
      VStack(alignment: .leading, spacing: 2) {
        Text(IndiaClock.whenLine(item, at: now))
          .font(.system(size: 12, weight: .semibold))
          .lineLimit(1)
          .foregroundColor(palette.accent)
        Text(item.name)
          .font(.system(size: 16, weight: .semibold))
          .lineLimit(2)
          .foregroundColor(palette.ink)
        if !details.isEmpty {
          Text(details)
            .font(.system(size: 12))
            .lineLimit(1)
            .foregroundColor(palette.secondary)
        }
        Spacer(minLength: 6)
        if item.underReview {
          Pill(
            text: item.badge ?? "Under review", fill: palette.reviewFill,
            ink: palette.reviewInk, outline: nil)
        } else {
          Pill(
            text: "Show ticket ›", fill: palette.pillFill, ink: palette.pillInk,
            outline: palette.pillOutline)
        }
      }
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }
}

/// Signed out, or nothing coming up.
struct MessageView: View {
  let signedOut: Bool
  let medium: Bool
  let palette: NextUpPalette

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("MyOtherApp")
        .font(.system(size: 10, weight: .semibold))
        .textCase(.uppercase)
        .foregroundColor(palette.accent)
      Text(signedOut ? "Sign in to see your next event" : "Nothing coming up yet")
        .font(.system(size: medium ? 17 : 15, weight: .semibold))
        .lineLimit(3)
        .foregroundColor(palette.ink)
      Spacer(minLength: 6)
      Pill(
        text: signedOut ? "Sign in" : "Find events", fill: palette.pillFill,
        ink: palette.pillInk, outline: palette.pillOutline)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }
}

struct Pill: View {
  let text: String
  let fill: Color
  let ink: Color
  let outline: Color?

  var body: some View {
    Text(text)
      .font(.system(size: 12, weight: .semibold))
      .lineLimit(1)
      .foregroundColor(ink)
      .padding(.horizontal, 12)
      .padding(.vertical, 5)
      .background(Capsule().fill(fill))
      .overlay(Capsule().stroke(outline ?? .clear, lineWidth: 1))
  }
}

extension View {
  /// The widget's ground: iOS 17's container background (which keeps the
  /// system's margins), or a padded background before it.
  @ViewBuilder
  func nextUpBackground(_ color: Color) -> some View {
    if #available(iOSApplicationExtension 17.0, *) {
      containerBackground(for: .widget) { color }
    } else {
      padding(14).background(color)
    }
  }
}
