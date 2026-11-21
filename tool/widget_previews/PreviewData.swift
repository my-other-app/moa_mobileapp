import CoreGraphics
import Foundation

/// The widgets' faces, for the previews: made-up people and events.
enum PreviewData {
  /// The shared front page's picks (test/fixtures/widgets), as the Dart
  /// rules make them for someone in Tech.
  static let fixtures = URL(fileURLWithPath: CommandLine.arguments[3])

  static var forYouNow: Date {
    let expected = try! JSONSerialization.jsonObject(
      with: Data(contentsOf: fixtures.appendingPathComponent("for_you_expected.json")))
      as! [String: Any]
    return Date(timeIntervalSince1970: (expected["now"] as! NSNumber).doubleValue / 1000)
  }

  static var forYouSeveral: ForYouData {
    let body = try! Data(contentsOf: fixtures.appendingPathComponent("for_you_home.json"))
    return ForYouPicker.picked(
      body, for: ForYouData(header: nil, items: [], ask: ForYouAsk(api: ForYouData.defaultApi, topics: [3]),
        fetchedAt: 0, etag: nil), now: forYouNow, etag: nil)!
  }

  /// One event, from the platform's popular ones.
  static var forYouFew: ForYouData {
    let one = forYouSeveral.items.filter { $0.id == 107 }
    return ForYouData(header: "This week near you", items: one, ask: ForYouAsk(api: ForYouData.defaultApi),
      fetchedAt: 0, etag: nil)
  }

  static let forYouNone = ForYouData(
    header: nil, items: [], ask: ForYouAsk(api: ForYouData.defaultApi), fetchedAt: 1, etag: nil)

  /// The event-day card's clock: 7:15 am on DevFest's day, in India.
  static let eventDayNow = Date(timeIntervalSince1970: 1_795_830_300)

  static let eventDay: [(String, EventDayFace)] = {
    let start = Date(timeIntervalSince1970: 1_795_838_400)  // 9:30 am
    func face(_ phase: EventDayPhase) -> EventDayFace {
      EventDayFace(
        name: "DevFest Kochi 2026", place: "Le Méridien, Kochi", startsAt: start,
        endsAt: start.addingTimeInterval(8 * 3600), time: "9:30 am",
        link: URL(string: "https://myotherapp.in/events/1/ticket"), phase: phase)
    }
    return [("soon", face(.soon)), ("now", face(.now))]
  }()

  static let networking: [(String, NetworkingData)] = [
    ("ready", NetworkingData.parse(#"{"v":1,"state":"ready","name":"Asha Menon","profile_link":"https://myotherapp.in/p/abcdefghjk","network":12}"#)),
    ("no-qr", NetworkingData.parse(#"{"v":1,"state":"no_qr","name":"Asha Menon"}"#)),
    ("signed-out", NetworkingData.signedOut),
  ]

  /// The large widget: "Recently met" with four people, two with photos.
  static let networkingLarge = NetworkingData.parse(
    #"{"v":1,"state":"ready","name":"Asha Menon","profile_link":"https://myotherapp.in/p/abcdefghjk","network":12,"met":[{"name":"Ravi Kumar","initials":"RK","colour":0,"event":"DevFest Kochi","link":"https://myotherapp.in/network/41","photo":"networking_photo_41"},{"name":"Meera Das","initials":"MD","colour":1,"event":"DevFest Kochi","link":"https://myotherapp.in/network/40"},{"name":"Arjun Nair","initials":"AN","colour":2,"event":"Hack Night 04","link":"https://myotherapp.in/network/39","photo":"networking_photo_39"},{"name":"Fathima Rahman","initials":"FR","colour":3,"link":"https://myotherapp.in/network/38"}],"no_note":3}"#)

  /// The same, before anyone was saved.
  static let networkingEmpty = NetworkingData.parse(
    #"{"v":1,"state":"ready","name":"Asha Menon","profile_link":"https://myotherapp.in/p/abcdefghjk","network":0,"met":[],"no_note":0}"#)

  /// The code not read yet, with people.
  static let networkingNoQr = NetworkingData.parse(
    #"{"v":1,"state":"no_qr","name":"Asha Menon","met":[{"name":"Ravi Kumar","initials":"RK","colour":0,"event":"DevFest Kochi"},{"name":"Meera Das","initials":"MD","colour":1,"event":"DevFest Kochi"}],"no_note":1}"#)

  /// Stand-ins for two people's photos.
  static let photos: [String: CGImage] = [
    "networking_photo_41": photo(0x7A9CC6, 0xE8C39E),
    "networking_photo_39": photo(0x9B7E6B, 0xF1D9C4),
  ]

  /// A round "photo": a background and a head and shoulders.
  static func photo(_ ground: UInt32, _ skin: UInt32) -> CGImage {
    let side = 96
    let context = CGContext(
      data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    func colour(_ hex: UInt32) -> CGColor {
      CGColor(
        red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
    context.addEllipse(in: CGRect(x: 0, y: 0, width: side, height: side))
    context.clip()
    context.setFillColor(colour(ground))
    context.fill(CGRect(x: 0, y: 0, width: side, height: side))
    context.setFillColor(colour(skin))
    context.fillEllipse(in: CGRect(x: 30, y: 44, width: 36, height: 40))
    context.setFillColor(colour(0x2C333D))
    context.fillEllipse(in: CGRect(x: 14, y: -30, width: 68, height: 66))
    return context.makeImage()!
  }

  /// The previews' clock: Fri 27 Nov 2026, 10:00 am in India.
  static let now = Date(timeIntervalSince1970: 1_795_753_800)

  /// Next up with three events (one under review), from [now].
  static func nextUpThree(_ now: Date) -> NextUpData {
    func at(_ hours: Double) -> Int64 { Int64((now.timeIntervalSince1970 + hours * 3600) * 1000) }
    return NextUpData(
      v: 1, state: NextUpData.upcomingState, link: NextUpData.findEventsLink,
      items: [
        NextUpItem(
          eventId: 1, name: "DevFest Kochi 2026", startsAt: at(23.5), endsAt: at(31.5),
          weekday: "SAT", day: "28", month: "NOV", time: "9:30 am", date: "Sat, 28 Nov",
          place: "Le Méridien, Kochi", club: "GDG Kochi", review: false, badge: nil,
          link: "https://myotherapp.in/events/1/ticket"),
        NextUpItem(
          eventId: 2, name: "Hack Night 04", startsAt: at(104), endsAt: at(108),
          weekday: "TUE", day: "1", month: "DEC", time: "6:00 pm", date: "Tue, 1 Dec",
          place: "Online", club: "Kochi Coders", review: false, badge: nil,
          link: "https://myotherapp.in/events/2/ticket"),
        NextUpItem(
          eventId: 3, name: "Design Jam", startsAt: at(168), endsAt: at(192),
          weekday: "FRI", day: "4", month: "DEC", time: "10:00 am", date: "Fri, 4 Dec",
          place: nil, club: "Pixel Club", review: true, badge: "Under review",
          link: "https://myotherapp.in/events/design-jam"),
      ])
  }

  /// One event later today, for the lock screen's countdown.
  static func nextUpToday(_ now: Date) -> NextUpData {
    let start = Int64((now.timeIntervalSince1970 + 2.5 * 3600) * 1000)
    return NextUpData(
      v: 1, state: NextUpData.upcomingState, link: NextUpData.findEventsLink,
      items: [
        NextUpItem(
          eventId: 1, name: "DevFest Kochi 2026", startsAt: start, endsAt: start + 8 * 3_600_000,
          weekday: "FRI", day: "27", month: "NOV", time: "12:30 pm", date: "Fri, 27 Nov",
          place: "Le Méridien, Kochi", club: nil, review: false, badge: nil,
          link: "https://myotherapp.in/events/1/ticket")
      ])
  }
}
