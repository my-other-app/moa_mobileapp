import SwiftUI
#if os(iOS)
  import WidgetKit
#endif

/// "Next up" on the lock screen (iOS 16): what the system draws in its own
/// tint, so only shapes and words -- no colours of ours.
///
/// - **Card** (rectangular): "Next up", the event's name, and when --
///   "In 2 days", "Today · 9:30 am", "Happening now".
/// - **Line** (inline, above the clock): "DevFest · in 2 days".
/// - **Round** (circular): the day of the month under its month; on the day
///   itself a countdown the system keeps running; "now" once it started.
///
/// The words that depend on the clock move on at the timeline's entries
/// (each midnight in India, each start and end); the countdown runs on its
/// own. Only the event's name and its time are shown -- nothing of the
/// ticket -- and a tap (after unlocking) opens the ticket in the app.
@available(iOS 16.0, macOS 13.0, *)
struct NextUpAccessory: View {
  let data: NextUpData
  let now: Date
  let shape: AccessoryShape

  var body: some View {
    let item = data.next(at: now)
    switch shape {
    case .rectangular:
      NextUpCard(item: item, signedOut: data.state == NextUpData.signedOutState, now: now)
    case .inline:
      NextUpLine(item: item, signedOut: data.state == NextUpData.signedOutState, now: now)
    case .circular:
      NextUpRound(item: item, now: now)
    }
  }
}

struct NextUpCard: View {
  let item: NextUpItem?
  let signedOut: Bool
  let now: Date

  var body: some View {
    VStack(alignment: .leading, spacing: 1) {
      HStack(spacing: 4) {
        Image(systemName: "ticket")
          .font(.system(size: 11, weight: .semibold))
        Text(item == nil ? "MyOtherApp" : "Next up")
          .font(WidgetFonts.text(12, .semibold))
          .textCase(.uppercase)
      }
      .accentable()
      if let item = item {
        Text(item.name)
          .font(WidgetFonts.text(15, .semibold))
          .lineLimit(1)
        Text(IndiaClock.whenLine(item, at: now))
          .font(WidgetFonts.text(13))
          .lineLimit(1)
      } else {
        Text(signedOut ? "Sign in to see your next event" : "Nothing coming up yet")
          .font(WidgetFonts.text(14, .semibold))
          .lineLimit(2)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
  }
}

struct NextUpLine: View {
  let item: NextUpItem?
  let signedOut: Bool
  let now: Date

  var body: some View {
    if let item = item {
      Label(IndiaClock.inlineLine(item, at: now), systemImage: "ticket")
    } else {
      Label(signedOut ? "Sign in to MyOtherApp" : "No events coming up", systemImage: "ticket")
    }
  }
}

@available(iOS 16.0, macOS 13.0, *)
struct NextUpRound: View {
  let item: NextUpItem?
  let now: Date

  var body: some View {
    ZStack {
      AccessoryDisc()
      face
        .multilineTextAlignment(.center)
        .padding(5)
    }
  }

  @ViewBuilder
  private var face: some View {
    switch item.map({ IndiaClock.circleFace($0, at: now) }) {
    case .day(let day, let month)?:
      VStack(spacing: -3) {
        Text(month)
          .font(WidgetFonts.display(13))
          .accentable()
        Text(day)
          .font(WidgetFonts.display(28))
          .minimumScaleFactor(0.6)
      }
      .lineLimit(1)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(item?.date ?? "\(day) \(month)")
    case .countdown(let start)?:
      VStack(spacing: 0) {
        Text("In")
          .font(WidgetFonts.text(10, .semibold))
          .textCase(.uppercase)
          .accentable()
        Text(timerInterval: now...max(now, start), countsDown: true, showsHours: true)
          .font(WidgetFonts.text(13, .semibold))
          .monospacedDigit()
          .lineLimit(1)
          .minimumScaleFactor(0.6)
      }
    case .now?:
      VStack(spacing: 0) {
        Image(systemName: "ticket")
          .font(.system(size: 13, weight: .semibold))
          .accentable()
        Text("Now")
          .font(WidgetFonts.text(13, .semibold))
          .textCase(.uppercase)
      }
    case .undated?, nil:
      Image(systemName: "ticket")
        .font(.system(size: 20, weight: .medium))
        .accessibilityLabel(item == nil ? "No events coming up" : "Date to be announced")
    }
  }
}

/// The glyph on the lock screen's disc, with "My QR" under it.
struct MyQrLockView: View {
  var body: some View {
    ZStack {
      AccessoryDisc()
      VStack(spacing: 1) {
        Image(systemName: "qrcode")
          .font(.system(size: 21, weight: .medium))
          .accentable()
        Text("My QR")
          .font(WidgetFonts.text(9, .semibold))
          .textCase(.uppercase)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Open My QR")
  }
}

/// The soft disc behind a round lock-screen widget.
struct AccessoryDisc: View {
  var body: some View {
    #if os(iOS)
      if #available(iOSApplicationExtension 16.0, *) {
        AccessoryWidgetBackground()
      } else {
        Circle().fill(Color.white.opacity(0.18))
      }
    #else
      Circle().fill(Color.white.opacity(0.18))
    #endif
  }
}
