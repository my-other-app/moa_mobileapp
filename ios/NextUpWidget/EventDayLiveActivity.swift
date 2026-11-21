#if os(iOS) && canImport(ActivityKit)
  import ActivityKit
  import SwiftUI
  import WidgetKit

  /// The event-day card as a Live Activity (iOS 16.1): the lock screen's
  /// card and the Dynamic Island (EventDayViews.swift). The app starts,
  /// updates and ends it (ios/Runner/EventDayActivities.swift); nothing is
  /// pushed. Its face moves on by itself: the countdown runs on the system's
  /// clock, and from iOS 16.2 the content goes stale at the start (then at
  /// the end), which turns the countdown into "Happening now".
  @available(iOS 16.1, *)
  struct EventDayLiveActivity: Widget {
    var body: some WidgetConfiguration {
      ActivityConfiguration(for: EventDayAttributes.self) { context in
        EventDayLockScreen(face: EventDayLiveActivity.face(context))
      } dynamicIsland: { context in
        let face = EventDayLiveActivity.face(context)
        return DynamicIsland {
          DynamicIslandExpandedRegion(.center) {
            EventDayIsland.ExpandedTop(face: face, now: Date())
          }
          DynamicIslandExpandedRegion(.bottom) {
            EventDayIsland.ExpandedBottom(face: face)
          }
        } compactLeading: {
          EventDayIsland.Leading()
        } compactTrailing: {
          EventDayIsland.Trailing(face: face, now: Date())
        } minimal: {
          EventDayIsland.Minimal()
        }
        .widgetURL(face.link)
        .keylineTint(EventDayIsland.palette.accent)
      }
    }

    /// What to draw: the app's word on whether the event started, moved on
    /// by the stale date when the app hasn't run since.
    static func face(_ context: ActivityViewContext<EventDayAttributes>) -> EventDayFace {
      let state = context.state
      var stale = false
      if #available(iOS 16.2, *) { stale = context.isStale }
      let phase: EventDayPhase
      switch (state.started, stale) {
      case (false, false): phase = .soon
      case (true, true): phase = .over
      default: phase = .now
      }
      return EventDayFace(
        name: state.name, place: state.place, startsAt: state.startsAt, endsAt: state.endsAt,
        time: state.time,
        link: EventDayClock.isSiteLink(context.attributes.link)
          ? URL(string: context.attributes.link) : nil,
        phase: phase)
    }
  }

  /// The lock screen's card, in the app's colours for the lock screen's
  /// light or dark look.
  @available(iOS 16.1, *)
  struct EventDayLockScreen: View {
    let face: EventDayFace

    @Environment(\.colorScheme) private var scheme

    var body: some View {
      let palette = WidgetPalette.of(scheme)
      EventDayLockView(face: face, now: Date(), palette: palette)
        .widgetURL(face.link)
        .activityBackgroundTint(palette.background)
        .activitySystemActionForegroundColor(palette.ink)
    }
  }
#endif
