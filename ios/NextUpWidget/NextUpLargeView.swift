import SwiftUI

/// "Next up", large: the next three events, soonest first. The first has
/// the medium widget's look -- the date, when, the name, the time and the
/// place, and "Show ticket" (or what stands in for it); the two after it a
/// smaller date and one line each. Each row opens its own ticket (or the
/// event, for a registration under review); fewer than three leave room for
/// "Find events".
struct LargeEventsView: View {
  let items: [NextUpItem]
  let now: Date
  let palette: WidgetPalette

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("Next up")
        .font(WidgetFonts.text(11, .semibold))
        .textCase(.uppercase)
        .foregroundColor(palette.accent)
        .padding(.bottom, 8)
      if let first = items.first {
        WidgetLink(destination: first.url ?? URL(string: NextUpData.findEventsLink)!) {
          FirstEventRow(item: first, now: now, palette: palette)
        }
      }
      ForEach(Array(items.dropFirst().enumerated()), id: \.offset) { _, item in
        Rectangle()
          .fill(palette.secondary.opacity(0.18))
          .frame(height: 1)
          .padding(.vertical, 9)
        WidgetLink(destination: item.url ?? URL(string: NextUpData.findEventsLink)!) {
          LaterEventRow(item: item, now: now, palette: palette)
        }
      }
      Spacer(minLength: 0)
      if items.count < NextUpContent.largeRows {
        WidgetLink(destination: URL(string: NextUpData.findEventsLink)!) {
          Text("Find more events ›")
            .font(WidgetFonts.text(12, .semibold))
            .foregroundColor(palette.accent)
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }
}

/// The next event, as the medium widget draws it.
struct FirstEventRow: View {
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
        Group {
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
        .padding(.top, 6)
      }
      Spacer(minLength: 0)
    }
  }
}

/// An event after the next: a smaller date, when, the name and the place.
struct LaterEventRow: View {
  let item: NextUpItem
  let now: Date
  let palette: WidgetPalette

  private var when: String {
    let line = IndiaClock.whenLine(item, at: now)
    return item.underReview ? "\(line) · \(item.badge ?? "Under review")" : line
  }

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      DateBlock(item: item, large: false, palette: palette)
      VStack(alignment: .leading, spacing: 1) {
        Text(when)
          .font(WidgetFonts.text(11, .semibold))
          .lineLimit(1)
          .foregroundColor(palette.accent)
        Text(item.name)
          .font(WidgetFonts.text(14, .semibold))
          .lineLimit(1)
          .foregroundColor(palette.ink)
        if let place = item.place ?? item.club {
          Text(place)
            .font(WidgetFonts.text(12))
            .lineLimit(1)
            .foregroundColor(palette.secondary)
        }
      }
      Spacer(minLength: 0)
    }
  }
}
