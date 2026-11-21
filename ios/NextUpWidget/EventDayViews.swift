import SwiftUI

// The event-day card's faces (EventDayLiveActivity.swift draws them in the
// Live Activity; the Mac previews draw them too): the lock screen's card and
// the Dynamic Island's compact, minimal and expanded shapes.
//
// Before the start a countdown the system runs by itself
// (`Text(timerInterval:)`); from the start "Happening now" and when it ends;
// the venue, and "Show ticket". Nothing of the ticket is drawn.

/// The countdown to [to], as the system runs it ("2:15:04"); it stops at
/// zero.
@available(iOS 16.0, macOS 13.0, *)
struct EventDayCountdown: View {
  let to: Date
  let now: Date

  var body: some View {
    Text(timerInterval: min(now, to)...to, countsDown: true)
      .monospacedDigit()
  }
}

/// The lock screen's card.
@available(iOS 16.0, macOS 13.0, *)
struct EventDayLockView: View {
  let face: EventDayFace
  let now: Date
  let palette: WidgetPalette

  private var label: String {
    switch face.phase {
    case .soon: return "Starts in"
    case .now: return face.time.isEmpty ? "Happening now" : "Started \(face.time)"
    case .over: return "That’s a wrap"
    }
  }

  private var details: String {
    let when = face.phase == .soon ? face.time : face.untilLine
    return [when, face.place].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
  }

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      VStack(alignment: .leading, spacing: 1) {
        HStack(spacing: 5) {
          Image(systemName: "ticket.fill").font(.system(size: 11, weight: .semibold))
          Text(label)
            .font(WidgetFonts.text(11, .semibold))
            .textCase(.uppercase)
            .lineLimit(1)
        }
        .foregroundColor(palette.accent)
        Group {
          if face.phase == .soon {
            EventDayCountdown(to: face.startsAt, now: now)
          } else {
            Text(face.phase == .now ? "Now" : "Over")
          }
        }
        .font(WidgetFonts.display(38))
        .lineLimit(1)
        .foregroundColor(palette.ink)
        Text(face.name)
          .font(WidgetFonts.text(15, .semibold))
          .lineLimit(1)
          .foregroundColor(palette.ink)
        if !details.isEmpty {
          Text(details)
            .font(WidgetFonts.text(12))
            .lineLimit(1)
            .foregroundColor(palette.secondary)
        }
      }
      Spacer(minLength: 0)
      if face.phase != .over {
        EventDayTicketButton(link: face.link, palette: palette)
      }
    }
    .padding(16)
  }
}

/// "Show ticket ›": the app's yellow pill. Opens the ticket in the app.
@available(iOS 16.0, macOS 13.0, *)
struct EventDayTicketButton: View {
  let link: URL?
  let palette: WidgetPalette

  var body: some View {
    let pill = Pill(
      text: "Show ticket ›", fill: palette.pillFill, ink: palette.pillInk,
      outline: palette.pillOutline)
    if let link = link {
      WidgetLink(destination: link) { pill }
    } else {
      pill
    }
  }
}

/// The Dynamic Island's pieces. The island is always black: the dark
/// palette's words on it.
@available(iOS 16.0, macOS 13.0, *)
enum EventDayIsland {
  static let palette = WidgetPalette.of(.dark)

  /// Left of the camera: a ticket.
  struct Leading: View {
    var body: some View {
      Image(systemName: "ticket.fill")
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(EventDayIsland.palette.accent)
    }
  }

  /// Right of the camera: the countdown, or "Now".
  struct Trailing: View {
    let face: EventDayFace
    let now: Date

    var body: some View {
      Group {
        if face.phase == .soon {
          EventDayCountdown(to: face.startsAt, now: now)
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: 58)
        } else {
          Text(face.phase == .now ? "Now" : "Over")
        }
      }
      .font(WidgetFonts.text(14, .semibold))
      .foregroundColor(EventDayIsland.palette.accent)
    }
  }

  /// Sharing the island with another app: just the ticket.
  struct Minimal: View {
    var body: some View {
      Image(systemName: "ticket.fill")
        .font(.system(size: 12, weight: .semibold))
        .foregroundColor(EventDayIsland.palette.accent)
    }
  }

  /// Expanded (touch and hold): the label and countdown on top, the name
  /// and place, and "Show ticket".
  struct ExpandedTop: View {
    let face: EventDayFace
    let now: Date

    var body: some View {
      HStack(alignment: .firstTextBaseline) {
        Label(
          face.phase == .soon
            ? "Starts in" : (face.time.isEmpty ? "Happening now" : "Started \(face.time)"),
          systemImage: "ticket.fill")
          .font(WidgetFonts.text(12, .semibold))
          .textCase(.uppercase)
          .foregroundColor(EventDayIsland.palette.accent)
          .lineLimit(1)
        Spacer(minLength: 8)
        Group {
          if face.phase == .soon {
            EventDayCountdown(to: face.startsAt, now: now)
              .multilineTextAlignment(.trailing)
          } else {
            Text(face.phase == .now ? "Now" : "Over")
          }
        }
        .font(WidgetFonts.display(28))
        .foregroundColor(.white)
        .lineLimit(1)
      }
    }
  }

  struct ExpandedBottom: View {
    let face: EventDayFace

    var body: some View {
      HStack(alignment: .center, spacing: 10) {
        VStack(alignment: .leading, spacing: 1) {
          Text(face.name)
            .font(WidgetFonts.text(15, .semibold))
            .lineLimit(1)
            .foregroundColor(.white)
          Text(
            [face.phase == .soon ? face.time : face.untilLine, face.place]
              .compactMap { $0 }.joined(separator: " · ")
          )
          .font(WidgetFonts.text(12))
          .lineLimit(1)
          .foregroundColor(EventDayIsland.palette.secondary)
        }
        Spacer(minLength: 0)
        if face.phase != .over {
          EventDayTicketButton(link: face.link, palette: EventDayIsland.palette)
        }
      }
    }
  }
}
