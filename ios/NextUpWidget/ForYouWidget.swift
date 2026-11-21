import SwiftUI
import WidgetKit

/// "For you", the events widget (docs/HOME_WIDGETS.md): what is on this
/// week -- the person's topics first, then near them -- then the platform's
/// popular events. Medium lists two, large four; each row (date, name,
/// club, place or "Online") opens that event's page in the app, "See all"
/// the events directory. Nothing on: a calm "Find events".
///
/// The app writes the list whenever it reads its front page (ForYouData).
/// While the app is closed the timeline asks the same public page itself
/// (ForYouFetch) every few hours -- well inside the system's budget -- and
/// keeps an entry for each listed event's end, so an event over drops off.
struct ForYouWidget: Widget {
  /// The kind the app reloads (ForYouKind.iOSKind in Dart).
  let kind = "ForYouWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: ForYouProvider()) { entry in
      ForYouView(entry: entry)
    }
    .configurationDisplayName("For you")
    .description("Events this week: in your topics and near you.")
    .supportedFamilies([.systemMedium, .systemLarge])
  }
}

struct ForYouEntry: TimelineEntry {
  let date: Date
  let data: ForYouData
}

struct ForYouProvider: TimelineProvider {
  func placeholder(in context: Context) -> ForYouEntry {
    ForYouEntry(date: Date(), data: .sample(Date()))
  }

  func getSnapshot(in context: Context, completion: @escaping (ForYouEntry) -> Void) {
    let now = Date()
    let data = ForYouData.read()
    // The gallery shows an example rather than an empty list.
    if context.isPreview && data.upcoming(at: now, limit: 1).isEmpty {
      completion(ForYouEntry(date: now, data: .sample(now)))
    } else {
      completion(ForYouEntry(date: now, data: data))
    }
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<ForYouEntry>) -> Void) {
    let now = Date()
    let data = ForYouData.read()
    guard data.isDue(at: now) else {
      completion(ForYouProvider.timeline(data, now: now))
      return
    }
    ForYouFetch.refresh(data, now: now) { fresh in
      completion(ForYouProvider.timeline(fresh, now: now))
    }
  }

  /// An entry now and at each listed event's end (within the refresh), then
  /// asked again: a few hours after the last read, or soon after a failed
  /// one.
  static func timeline(_ data: ForYouData, now: Date) -> Timeline<ForYouEntry> {
    let nowMs = IndiaClock.millis(now)
    let read = Date(timeIntervalSince1970: TimeInterval(data.fetchedAt) / 1000)
    let next =
      data.isDue(at: now)
      ? now.addingTimeInterval(30 * 60)
      : read.addingTimeInterval(ForYouData.refreshEvery)
    let ends = data.items.compactMap { $0.endsAt }
      .filter { $0 > nowMs && IndiaClock.date($0) < next }
      .map(IndiaClock.date)
    let moments = [now] + Set(ends).sorted()
    return Timeline(
      entries: moments.map { ForYouEntry(date: $0, data: data) }, policy: .after(max(next, now)))
  }
}

// MARK: - Views

struct ForYouView: View {
  let entry: ForYouEntry

  @Environment(\.widgetFamily) private var family
  @Environment(\.colorScheme) private var scheme

  var body: some View {
    let palette = WidgetPalette.of(scheme)
    ForYouContent(
      data: entry.data, now: entry.date, large: family == .systemLarge, palette: palette
    )
    .widgetURL(entry.data.seeAllURL)
    .widgetBackground(palette.background)
  }
}

/// What the widget shows, for a size: apart from the environment so the
/// previews can draw each size and theme.
struct ForYouContent: View {
  let data: ForYouData
  let now: Date
  let large: Bool
  let palette: WidgetPalette

  private var rows: Int { large ? ForYouData.largeRows : ForYouData.mediumRows }

  var body: some View {
    let items = data.upcoming(at: now, limit: rows)
    if items.isEmpty {
      ForYouEmptyView(large: large, palette: palette)
    } else {
      VStack(alignment: .leading, spacing: 0) {
        HStack(alignment: .firstTextBaseline) {
          Text(data.header ?? "For you")
            .font(WidgetFonts.text(11, .semibold))
            .textCase(.uppercase)
            .lineLimit(1)
            .foregroundColor(palette.accent)
          Spacer(minLength: 8)
          WidgetLink(destination: data.seeAllURL) {
            Text("See all ›")
              .font(WidgetFonts.text(12, .semibold))
              .lineLimit(1)
              .foregroundColor(palette.accent)
          }
        }
        .padding(.bottom, large ? 10 : 8)
        ForEach(Array(items.enumerated()), id: \.offset) { index, item in
          if index > 0 {
            Rectangle()
              .fill(palette.secondary.opacity(0.18))
              .frame(height: 1)
              .padding(.vertical, large ? 8 : 6)
          }
          WidgetLink(destination: item.url ?? data.seeAllURL) {
            ForYouRow(item: item, palette: palette)
          }
        }
        if large && items.count < rows {
          WidgetLink(destination: data.seeAllURL) {
            SoftPanel(
              symbol: "calendar", text: "That’s what’s on for now",
              action: "Find more events ›", palette: palette)
          }
          .padding(.top, 12)
        } else {
          Spacer(minLength: 0)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
  }
}

/// One event: a small date leaf, the name, the club and the place.
struct ForYouRow: View {
  let item: ForYouItem
  let palette: WidgetPalette

  var body: some View {
    HStack(alignment: .center, spacing: 10) {
      DateLeaf(weekday: item.weekday, day: item.day, month: item.month, label: item.date, palette: palette)
      VStack(alignment: .leading, spacing: 1) {
        Text(item.name)
          .font(WidgetFonts.text(14, .semibold))
          .lineLimit(1)
          .foregroundColor(palette.ink)
        Text(item.time.isEmpty ? item.details : "\(item.time) · \(item.details)")
          .font(WidgetFonts.text(12))
          .lineLimit(1)
          .foregroundColor(palette.secondary)
      }
      Spacer(minLength: 0)
    }
  }
}

/// The date as a small leaf -- weekday, day, month in Bebas Neue -- for a
/// list's rows (Next up's date block, smaller).
struct DateLeaf: View {
  let weekday: String
  let day: String
  let month: String
  let label: String
  let palette: WidgetPalette

  var body: some View {
    VStack(spacing: -2) {
      Text(weekday).font(WidgetFonts.display(10))
      Text(day).font(WidgetFonts.display(22)).minimumScaleFactor(0.6)
      Text(month).font(WidgetFonts.display(10))
    }
    .lineLimit(1)
    .foregroundColor(palette.dateInk)
    .frame(width: 40, height: 46)
    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(palette.dateFill))
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(label)
  }
}

/// Nothing on (or nothing read yet): a calm "Find events".
struct ForYouEmptyView: View {
  let large: Bool
  let palette: WidgetPalette

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("For you")
        .font(WidgetFonts.text(11, .semibold))
        .textCase(.uppercase)
        .foregroundColor(palette.accent)
      Text("Nothing on this week yet")
        .font(WidgetFonts.text(large ? 18 : 16, .semibold))
        .lineLimit(2)
        .foregroundColor(palette.ink)
      Text("New events show here as clubs add them.")
        .font(WidgetFonts.text(12))
        .lineLimit(2)
        .foregroundColor(palette.secondary)
      Spacer(minLength: 6)
      Pill(
        text: "Find events", fill: palette.pillFill, ink: palette.pillInk,
        outline: palette.pillOutline)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }
}
