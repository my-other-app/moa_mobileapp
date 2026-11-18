import Flutter
import Foundation

#if canImport(ActivityKit)
  import ActivityKit
#endif

// MARK: - The event-day card (Live Activity)
/// Starts, updates and ends the event-day card from Dart
/// (lib/features/home_widget/data/event_day_platform.dart,
/// docs/HOME_WIDGETS.md "Event-day card"): a Live Activity
/// (ios/NextUpWidget/EventDayAttributes.swift, drawn by the widget
/// extension), iOS 16.1 and later. One at a time; local only, nothing is
/// pushed.
///
/// The card is given the event's name, venue, start, end, time of day and
/// the ticket's page in the app -- never the ticket's code. Starting it
/// before the event, its content goes stale at the start (iOS 16.2), which
/// the card draws as "Happening now"; once the event is on, with its end
/// within four hours, it is ended at once and kept on the lock screen until
/// the end, when the system takes it away; after the end it goes.
enum EventDayActivities {
  static let channelName = "finnet/event_day"

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      guard #available(iOS 16.1, *) else {
        switch call.method {
        case "supported", "start", "update": result(false)
        case "end", "current": result(nil)
        default: result(FlutterMethodNotImplemented)
        }
        return
      }
      switch call.method {
      case "supported":
        result(true)
      case "start", "update":
        guard let card = EventDayCard(call.arguments) else {
          result(FlutterError(code: "bad_card", message: "a card is a map", details: nil))
          return
        }
        let starting = call.method == "start"
        Task {
          let shown = starting ? await EventDayLive.start(card) : await EventDayLive.update(card)
          DispatchQueue.main.async { result(shown) }
        }
      case "end":
        Task {
          await EventDayLive.endAll()
          DispatchQueue.main.async { result(nil) }
        }
      case "current":
        result(EventDayLive.current())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

/// A card as Dart sends it (EventDayCard.toChannel).
struct EventDayCard {
  let eventId: Int
  let name: String
  let place: String?
  let startsAt: Date
  let endsAt: Date
  let time: String
  let link: String

  init?(_ arguments: Any?) {
    guard let map = arguments as? [String: Any],
      let id = (map["event_id"] as? NSNumber)?.intValue, id > 0,
      let name = map["name"] as? String,
      let start = (map["starts_at"] as? NSNumber)?.doubleValue,
      let end = (map["ends_at"] as? NSNumber)?.doubleValue, end > start,
      let link = map["link"] as? String, EventDayClock.isSiteLink(link)
    else { return nil }
    self.eventId = id
    self.name = name
    self.place = map["place"] as? String
    self.startsAt = Date(timeIntervalSince1970: start / 1000)
    self.endsAt = Date(timeIntervalSince1970: end / 1000)
    self.time = map["time"] as? String ?? ""
    self.link = link
  }
}

#if canImport(ActivityKit)
  @available(iOS 16.1, *)
  enum EventDayLive {
    typealias Card = Activity<EventDayAttributes>

    /// The cards still on screen: running, gone stale, or ended and kept on
    /// the lock screen until they go.
    static func onScreen() -> [Card] {
      Card.activities.filter { activity in
        switch activity.activityState {
        case .active, .ended: return true
        case .dismissed: return false
        default: return true  // .stale (iOS 16.2)
        }
      }
    }

    /// The event whose card is up.
    static func current() -> Int? { onScreen().first?.attributes.eventId }

    static func state(_ card: EventDayCard, now: Date) -> EventDayAttributes.ContentState {
      EventDayAttributes.ContentState(
        name: card.name, place: card.place, startsAt: card.startsAt, endsAt: card.endsAt,
        time: card.time,
        started: EventDayClock.phase(startsAt: card.startsAt, endsAt: card.endsAt, now: now) != .soon
      )
    }

    /// Put [card] up, taking any other down. False when Live Activities are
    /// off for the app, the event is over, or the system refused.
    static func start(_ card: EventDayCard) async -> Bool {
      let now = Date()
      guard ActivityAuthorizationInfo().areActivitiesEnabled,
        EventDayClock.phase(startsAt: card.startsAt, endsAt: card.endsAt, now: now) != .over
      else { return false }
      // Already up for this event: brought up to date instead.
      if onScreen().contains(where: { $0.attributes.eventId == card.eventId }) {
        return await update(card)
      }
      await endAll()
      let attributes = EventDayAttributes(eventId: card.eventId, link: card.link)
      let state = state(card, now: now)
      do {
        let activity: Card
        if #available(iOS 16.2, *) {
          activity = try Card.request(
            attributes: attributes,
            content: ActivityContent(
              state: state,
              staleDate: EventDayClock.staleDate(
                startsAt: card.startsAt, endsAt: card.endsAt, now: now)),
            pushType: nil)
        } else {
          activity = try Card.request(attributes: attributes, contentState: state, pushType: nil)
        }
        if EventDayClock.endsByItself(startsAt: card.startsAt, endsAt: card.endsAt, now: now) {
          await endKept(activity, state: state, until: card.endsAt)
        }
        return true
      } catch {
        return false
      }
    }

    /// Bring the card for [card]'s event up to date. False when none is up.
    static func update(_ card: EventDayCard) async -> Bool {
      let now = Date()
      guard let activity = onScreen().first(where: { $0.attributes.eventId == card.eventId })
      else { return false }
      // Ended already, kept on the lock screen until it goes by itself.
      if activity.activityState == .ended { return true }
      let phase = EventDayClock.phase(startsAt: card.startsAt, endsAt: card.endsAt, now: now)
      let state = state(card, now: now)
      if phase == .over {
        await end(activity, immediately: true)
        return false
      }
      if EventDayClock.endsByItself(startsAt: card.startsAt, endsAt: card.endsAt, now: now) {
        await endKept(activity, state: state, until: card.endsAt)
        return true
      }
      if #available(iOS 16.2, *) {
        await activity.update(
          ActivityContent(
            state: state,
            staleDate: EventDayClock.staleDate(
              startsAt: card.startsAt, endsAt: card.endsAt, now: now)))
      } else {
        await activity.update(using: state)
      }
      return true
    }

    /// Every card down, at once.
    static func endAll() async {
      for activity in Card.activities {
        await end(activity, immediately: true)
      }
    }

    private static func end(_ activity: Card, immediately: Bool) async {
      if #available(iOS 16.2, *) {
        await activity.end(nil, dismissalPolicy: .immediate)
      } else {
        await activity.end(using: nil, dismissalPolicy: .immediate)
      }
    }

    /// Ended now, kept on the lock screen until [until] (at most four
    /// hours), when the system takes it away.
    private static func endKept(
      _ activity: Card, state: EventDayAttributes.ContentState, until: Date
    ) async {
      if #available(iOS 16.2, *) {
        await activity.end(
          ActivityContent(state: state, staleDate: nil), dismissalPolicy: .after(until))
      } else {
        await activity.end(using: state, dismissalPolicy: .after(until))
      }
    }
  }
#endif
