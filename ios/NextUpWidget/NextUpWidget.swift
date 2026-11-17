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
struct NextUpWidget: Widget {
  /// The kind the app reloads (NextUpKind.iOSKind in Dart).
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

// MARK: - Views

struct NextUpView: View {
  let entry: NextUpEntry

  @Environment(\.widgetFamily) private var family
  @Environment(\.colorScheme) private var scheme

  var body: some View {
    let palette = WidgetPalette.of(scheme)
    NextUpContent(
      data: entry.data, now: entry.date, medium: family == .systemMedium, palette: palette
    )
    .widgetURL(entry.data.next(at: entry.date)?.url ?? entry.data.messageLink)
    .widgetBackground(palette.background)
  }
}

/// What the widget shows, for a size: apart from the environment so the
/// previews can draw each size and theme.
struct NextUpContent: View {
  let data: NextUpData
  let now: Date
  let medium: Bool
  let palette: WidgetPalette

  var body: some View {
    if let item = data.next(at: now) {
      if medium {
        MediumEventView(item: item, now: now, palette: palette)
      } else {
        SmallEventView(item: item, now: now, palette: palette)
      }
    } else {
      MessageView(
        signedOut: data.state == NextUpData.signedOutState, medium: medium, palette: palette)
    }
  }
}

/// The date block: weekday, day, month, in Bebas Neue.
struct DateBlock: View {
  let item: NextUpItem
  let large: Bool
  let palette: WidgetPalette

  var body: some View {
    VStack(spacing: large ? -4 : -2) {
      Text(item.day == nil ? "" : (item.weekday ?? ""))
        .font(WidgetFonts.display(large ? 14 : 12))
      Text(item.day ?? "—")
        .font(WidgetFonts.display(large ? 38 : 30))
        .minimumScaleFactor(0.6)
      Text(item.day == nil ? "TBA" : (item.month ?? ""))
        .font(WidgetFonts.display(large ? 14 : 12))
    }
    .lineLimit(1)
    .foregroundColor(palette.dateInk)
    .frame(minWidth: large ? 54 : 44)
    .padding(.horizontal, large ? 6 : 4)
    .padding(.top, large ? 6 : 5)
    .padding(.bottom, large ? 5 : 4)
    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(palette.dateFill))
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(item.date ?? "Date to be announced")
  }
}

struct SmallEventView: View {
  let item: NextUpItem
  let now: Date
  let palette: WidgetPalette

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(alignment: .top, spacing: 6) {
        DateBlock(item: item, large: false, palette: palette)
        Spacer(minLength: 0)
        Text(item.underReview ? (item.badge ?? "Under review") : "Next up")
          .font(WidgetFonts.text(10, .semibold))
          .textCase(.uppercase)
          .multilineTextAlignment(.trailing)
          .lineLimit(2)
          .foregroundColor(palette.accent)
      }
      Spacer(minLength: 6)
      Text(item.name)
        .font(WidgetFonts.text(15, .semibold))
        .lineLimit(2)
        .foregroundColor(palette.ink)
      Text(IndiaClock.whenLine(item, at: now))
        .font(WidgetFonts.text(12))
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
  let palette: WidgetPalette

  private var details: String {
    [item.time, item.place ?? item.club].compactMap { $0 }.joined(separator: " · ")
  }

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      DateBlock(item: item, large: true, palette: palette)
      VStack(alignment: .leading, spacing: 2) {
        Text(IndiaClock.whenLine(item, at: now))
          .font(WidgetFonts.text(12, .semibold))
          .lineLimit(1)
          .foregroundColor(palette.accent)
        Text(item.name)
          .font(WidgetFonts.text(16, .semibold))
          .lineLimit(2)
          .foregroundColor(palette.ink)
        if !details.isEmpty {
          Text(details)
            .font(WidgetFonts.text(12))
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
  let palette: WidgetPalette

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("MyOtherApp")
        .font(WidgetFonts.text(10, .semibold))
        .textCase(.uppercase)
        .foregroundColor(palette.accent)
      Text(signedOut ? "Sign in to see your next event" : "Nothing coming up yet")
        .font(WidgetFonts.text(medium ? 17 : 15, .semibold))
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
