package app.myotherapp.com.widget

import java.io.File
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * "For you"'s Kotlin rules (ForYouData.kt) against the Dart rules: the shared front page
 * (test/fixtures/widgets/for_you_home.json) and what the Dart tests hold the picks to
 * (for_you_expected.json). The same file checks the Swift rules (tool/widget_checks).
 */
class ForYouDataTest {
  private val fixtures: File by lazy {
    var dir: File? = File("").absoluteFile
    while (dir != null && !File(dir, "test/fixtures/widgets").isDirectory) dir = dir.parentFile
    File(dir ?: error("no test/fixtures/widgets above ${File("").absolutePath}"), "test/fixtures/widgets")
  }

  private fun read(name: String) = File(fixtures, name).readText()

  /** [value] with its keys sorted, to compare two answers. */
  private fun canonical(value: Any?): Any? =
      when (value) {
        is JSONObject -> value.keys().asSequence().sorted().associateWith { canonical(value.get(it)) }
        is JSONArray -> (0 until value.length()).map { canonical(value.get(it)) }
        is Int -> value.toLong()
        else -> value
      }

  @Test
  fun picksWhatTheDartRulesPick() {
    val home = JSONObject(read("for_you_home.json"))
    val expected = JSONObject(read("for_you_expected.json"))
    val now = expected.getLong("now")
    val cases = expected.getJSONArray("cases")
    for (i in 0 until cases.length()) {
      val case = cases.getJSONObject(i)
      val name = case.getString("name")
      val keep = case.getJSONObject("keep")
      val page = JSONObject(home.toString())
      if (!keep.getBoolean("week")) {
        page.put("this_week", JSONArray())
        page.put("near", JSONArray())
      }
      if (!keep.isNull("popular")) {
        val ids = keep.getJSONArray("popular").let { a -> (0 until a.length()).map { a.getLong(it) } }
        val all = home.getJSONArray("popular")
        page.put(
            "popular",
            JSONArray((0 until all.length()).map { all.getJSONObject(it) }.filter { it.getLong("id") in ids }))
      }
      val topics = case.getJSONArray("topics").let { a -> (0 until a.length()).map { a.getInt(it) } }
      val lists = ForYouPicker.lists(page)
      val pick = ForYouPicker.pick(lists.thisWeek, lists.near, lists.popular, topics, now)
      assertEquals("$name: header", if (case.isNull("header")) null else case.getString("header"), pick.header)
      assertEquals(
          "$name: items",
          canonical(case.getJSONArray("items")),
          canonical(JSONArray(pick.items.map { it.toJson() })))
    }
  }

  @Test
  fun writtenAndReadBack() {
    val now = JSONObject(read("for_you_expected.json")).getLong("now")
    val asked = ForYouData(null, emptyList(), ForYouAsk(ForYouData.DEFAULT_API, listOf(3)), 0L, null)
    val fresh = ForYouPicker.picked(read("for_you_home.json"), asked, now, "W/\"abc\"")!!
    val back = ForYouData.parse(fresh.toJson())
    assertEquals(listOf(101L, 105L, 103L, 104L, 107L, 108L), back.items.map { it.id })
    assertEquals("For you", back.header)
    assertEquals("W/\"abc\"", back.etag)
    assertFalse(back.isDueAt(now))
    assertTrue(back.isDueAt(now + ForYouData.REFRESH_EVERY_MS))
    assertTrue(ForYouData.unread.isDueAt(now))
    for (forbidden in listOf("poster", "going", "distance", "fee", "summary", "cdn.example")) {
      assertFalse(forbidden, fresh.toJson().contains(forbidden))
    }
    // An event over drops off the rows.
    assertEquals(
        listOf(105L, 103L, 104L, 107L), back.upcomingAt(now + 36 * 3600 * 1000L, 4).map { it.id })
  }

  @Test
  fun asksOnlyTheWebsitesApiOverHttps() {
    assertEquals(
        "https://api.myotherapp.in/api/v1/discover/home?lat=9.93&lng=76.27",
        ForYouAsk("https://api.myotherapp.in/api/v1/", lat = 9.93, lng = 76.27).homeUrl())
    assertEquals(
        "https://api.myotherapp.in/api/v1/discover/home",
        ForYouAsk("https://api.myotherapp.in/api/v1").homeUrl())
    assertNull(ForYouAsk("http://10.0.2.2:8000/api/v1").homeUrl())
    // A row whose link is not the website's is dropped.
    val odd =
        """{"v":1,"state":"events","items":[{"id":1,"name":"X","starts_at":1,"link":"https://evil.example/x"}]}"""
    assertTrue(ForYouData.parse(odd).items.isEmpty())
    assertEquals(ForYouData.unread, ForYouData.parse("""{"v":2}"""))
    assertEquals(ForYouData.unread, ForYouData.parse("not json"))
  }

  @Test
  fun readsTheServersTimes() {
    assertEquals(1_795_838_400_000L, ForYouCard.millis("2026-11-28T04:00:00+00:00"))
    assertEquals(1_795_838_400_000L, ForYouCard.millis("2026-11-28T09:30:00+05:30"))
    assertEquals(1_795_838_400_000L, ForYouCard.millis("2026-11-28T04:00:00Z"))
    assertEquals(1_795_838_400_250L, ForYouCard.millis("2026-11-28T04:00:00.250000+00:00"))
    assertNull(ForYouCard.millis("not a date"))
    assertNull(ForYouCard.millis(null))
    assertEquals("SAT", ForYouCard.india("EEE", 1_795_838_400_000L).uppercase())
    assertEquals("hack%20night", ForYouCard.encode("hack night"))
    assertEquals("caf%C3%A9-01", ForYouCard.encode("café-01"))
  }
}
