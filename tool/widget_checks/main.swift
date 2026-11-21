// Checks the widgets' Swift rules on a Mac (tool/widget_checks/run.sh):
//
// - "For you" (ForYouData.swift) picks from the shared front page
//   (test/fixtures/widgets/for_you_home.json) exactly what the Dart rules
//   pick (for_you_expected.json, which the Dart tests hold): the same
//   events, in the same order, with the same fields, and the same header;
// - the front page's times are read as the server writes them;
// - the event-day card's clock (EventDayAttributes.swift).
//
// Exits 1 on the first difference.

import Foundation

let dir = URL(fileURLWithPath: CommandLine.arguments[1])
var failures = 0

func check(_ ok: Bool, _ what: String) {
  if ok {
    print("ok   \(what)")
  } else {
    print("FAIL \(what)")
    failures += 1
  }
}

func load(_ name: String) -> [String: Any] {
  let data = try! Data(contentsOf: dir.appendingPathComponent(name))
  return try! JSONSerialization.jsonObject(with: data) as! [String: Any]
}

/// [value] as JSON text with sorted keys: to compare two answers.
func canonical(_ value: Any) -> String {
  let data = try! JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
  return String(data: data, encoding: .utf8)!
}

// MARK: - For you

let home = load("for_you_home.json")
let expected = load("for_you_expected.json")
let now = (expected["now"] as! NSNumber).int64Value

for testCase in expected["cases"] as! [[String: Any]] {
  let name = testCase["name"] as! String
  let keep = testCase["keep"] as! [String: Any]
  let week = keep["week"] as! Bool
  let popularIds = (keep["popular"] as? [NSNumber])?.map { $0.intValue }
  var page = home
  if !week {
    page["this_week"] = []
    page["near"] = []
  }
  if let ids = popularIds {
    page["popular"] = (home["popular"] as! [[String: Any]]).filter {
      ids.contains(($0["id"] as! NSNumber).intValue)
    }
  }
  let lists = ForYouPicker.lists(page)
  let topics = (testCase["topics"] as! [NSNumber]).map { $0.intValue }
  let result = ForYouPicker.pick(
    thisWeek: lists.thisWeek, near: lists.near, popular: lists.popular, topics: topics, now: now)
  check(
    result.header == testCase["header"] as? String,
    "\(name): header \(result.header ?? "none")")
  let mine = result.items.map { $0.json() }
  let theirs = testCase["items"] as! [[String: Any]]
  check(
    canonical(mine) == canonical(theirs),
    "\(name): \(result.items.map { $0.id }) as the Dart rules pick them")
}

// The whole round: the front page's bytes in, the widget's JSON out, and
// read back.
let body = try! Data(contentsOf: dir.appendingPathComponent("for_you_home.json"))
let asked = ForYouData(
  header: nil, items: [], ask: ForYouAsk(api: ForYouData.defaultApi, topics: [3]), fetchedAt: 0,
  etag: nil)
let at = Date(timeIntervalSince1970: TimeInterval(now) / 1000)
let fresh = ForYouPicker.picked(body, for: asked, now: at, etag: "W/\"abc\"")!
let text = String(data: try! JSONSerialization.data(withJSONObject: fresh.json()), encoding: .utf8)!
let back = ForYouData.parse(text)
check(back.items.map { $0.id } == [101, 105, 103, 104, 107, 108], "written and read back")
check(back.header == "For you" && back.etag == "W/\"abc\"", "header and ETag kept")
check(back.fetchedAt == now && !back.isDue(at: at), "read now: not asked again yet")
check(back.isDue(at: at.addingTimeInterval(3 * 3600)), "asked again three hours on")
check(ForYouData.unread.isDue(at: at), "nothing read: asked at once")
check(
  back.upcoming(at: at.addingTimeInterval(36 * 3600), limit: 4).map { $0.id } == [105, 103, 104, 107],
  "an event over drops off the rows")
for forbidden in ["poster", "going", "distance", "fee", "summary", "cdn.example"] {
  check(!text.contains(forbidden), "nothing but what it shows: no \(forbidden)")
}
check(
  ForYouAsk(api: "https://api.myotherapp.in/api/v1", lat: 9.93, lng: 76.27).homeURL?.absoluteString
    == "https://api.myotherapp.in/api/v1/discover/home?lat=9.93&lng=76.27", "the front page's address")
check(ForYouAsk(api: "http://10.0.2.2:8000/api/v1").homeURL == nil, "never over plain http")
check(
  ForYouData.parse(#"{"v":1,"state":"events","items":[{"id":1,"name":"X","starts_at":1,"link":"https://evil.example/x"}]}"#).items.isEmpty,
  "a row whose link is not the website's is dropped")

// MARK: - The server's times

check(ForYouCard.millis(iso: "2026-11-28T04:00:00+00:00") == 1_795_838_400_000, "UTC offset")
check(ForYouCard.millis(iso: "2026-11-28T09:30:00+05:30") == 1_795_838_400_000, "India offset")
check(ForYouCard.millis(iso: "2026-11-28T04:00:00Z") == 1_795_838_400_000, "Z")
check(ForYouCard.millis(iso: "2026-11-28T04:00:00.250000+00:00") == 1_795_838_400_250, "fraction")
check(ForYouCard.millis(iso: "not a date") == nil, "nonsense")

// MARK: - The event-day card

let start = Date(timeIntervalSince1970: 1_795_838_400)  // 9:30 am, 28 Nov, India
let end = start.addingTimeInterval(8 * 3600)
check(EventDayClock.phase(startsAt: start, endsAt: end, now: start.addingTimeInterval(-60)) == .soon, "before: soon")
check(EventDayClock.phase(startsAt: start, endsAt: end, now: start) == .now, "at the start: now")
check(EventDayClock.phase(startsAt: start, endsAt: end, now: end) == .over, "at the end: over")
check(EventDayClock.staleDate(startsAt: start, endsAt: end, now: start.addingTimeInterval(-60)) == start, "stale at the start")
check(EventDayClock.staleDate(startsAt: start, endsAt: end, now: start.addingTimeInterval(60)) == end, "then at the end")
check(!EventDayClock.endsByItself(startsAt: start, endsAt: end, now: start.addingTimeInterval(60)), "8 hours left: kept running")
check(EventDayClock.endsByItself(startsAt: start, endsAt: end, now: end.addingTimeInterval(-4 * 3600)), "4 hours left: ends by itself")
check(!EventDayClock.endsByItself(startsAt: start, endsAt: end, now: start.addingTimeInterval(-60)), "not before the start")
check(EventDayClock.isSiteLink("https://myotherapp.in/events/7/ticket"), "the ticket's page")
check(!EventDayClock.isSiteLink("https://myotherapp.in.example/x"), "not another site")
let face = EventDayFace(
  name: "DevFest", place: nil, startsAt: start, endsAt: end, time: "9:30 am", link: nil, phase: .now)
check(face.untilLine == "Until 5:30 pm", "until, in India")

print(failures == 0 ? "All checks passed." : "\(failures) failed.")
exit(failures == 0 ? 0 : 1)
