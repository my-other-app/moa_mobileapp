package app.myotherapp.com.widget

import org.json.JSONObject

/**
 * What the "Next up" widget shows, as the app wrote it (lib/features/home_widget/domain/next_up.dart,
 * docs/HOME_WIDGETS.md): one JSON string under [DATA_KEY] in home_widget's SharedPreferences.
 *
 * Nothing secret is in it -- no ticket code, no token -- only what the widget shows and the link a
 * tap opens.
 */
data class NextUpData(
    val state: String,
    val link: String,
    val items: List<NextUpItem>,
) {
  /** The event shown at [now]: the first one not over yet. */
  fun nextAt(now: Long): NextUpItem? = items.firstOrNull { !it.isOverAt(now) }

  companion object {
    /** The key the app keeps the JSON under (NextUpStore.dataKey). */
    const val DATA_KEY = "next_up"

    const val SIGNED_OUT = "signed_out"
    const val NOTHING = "nothing"
    const val UPCOMING = "upcoming"

    /** Where a tap goes with nothing written yet: sign in, then My events. */
    const val SIGN_IN_LINK = "https://myotherapp.in/me/tickets"

    /** Find events, on the website's address (the app opens it as Discover). */
    const val FIND_EVENTS_LINK = "https://myotherapp.in/events"

    /** Nothing written yet (the app never opened since install), or a version this build can't read. */
    val signedOut = NextUpData(SIGNED_OUT, SIGN_IN_LINK, emptyList())

    fun parse(json: String?): NextUpData {
      if (json.isNullOrBlank()) return signedOut
      return try {
        val root = JSONObject(json)
        if (root.optInt("v") != 1) return signedOut
        val state = root.optString("state", SIGNED_OUT)
        val list = root.optJSONArray("items")
        val items = mutableListOf<NextUpItem>()
        if (list != null) {
          for (i in 0 until list.length()) {
            val item = list.optJSONObject(i) ?: continue
            NextUpItem.from(item)?.let { items.add(it) }
          }
        }
        NextUpData(
            state = state,
            link = root.optString("link").ifBlank {
              if (state == SIGNED_OUT) SIGN_IN_LINK else FIND_EVENTS_LINK
            },
            items = items,
        )
      } catch (e: Exception) {
        signedOut
      }
    }
  }
}

data class NextUpItem(
    val eventId: Long,
    val name: String,
    val startsAt: Long?,
    val endsAt: Long?,
    val weekday: String?,
    val day: String?,
    val month: String?,
    val time: String?,
    val date: String?,
    val place: String?,
    val club: String?,
    val underReview: Boolean,
    val badge: String?,
    val link: String,
) {
  fun isOverAt(now: Long): Boolean = endsAt != null && now >= endsAt

  companion object {
    fun from(json: JSONObject): NextUpItem? {
      val name = json.optString("name").trim()
      val link = json.optString("link").trim()
      if (name.isEmpty() || link.isEmpty()) return null
      fun text(key: String): String? = json.optString(key).trim().ifEmpty { null }
      fun millis(key: String): Long? = if (json.has(key)) json.optLong(key) else null
      return NextUpItem(
          eventId = json.optLong("event_id"),
          name = name,
          startsAt = millis("starts_at"),
          endsAt = millis("ends_at"),
          weekday = text("weekday"),
          day = text("day"),
          month = text("month"),
          time = text("time"),
          date = text("date"),
          place = text("place"),
          club = text("club"),
          underReview = json.optBoolean("review", false),
          badge = text("badge"),
          link = link,
      )
    }
  }
}

/**
 * India's clock, for the widget's relative line. The same rules as `nextUpWhen` in
 * lib/features/home_widget/domain/next_up.dart; Asia/Kolkata is UTC+05:30 all year.
 */
object IndiaClock {
  private const val OFFSET_MS = (5 * 60 + 30) * 60 * 1000L
  private const val DAY_MS = 24 * 60 * 60 * 1000L

  /** The calendar day in India [millis] falls on, as a count of days. */
  fun dayOf(millis: Long): Long = Math.floorDiv(millis + OFFSET_MS, DAY_MS)

  /** The next midnight in India after [now]. */
  fun nextMidnight(now: Long): Long = (dayOf(now) + 1) * DAY_MS - OFFSET_MS

  /** "Today · 9:30 am", "Tomorrow · 9:30 am", "In 3 days", "Happening now". */
  fun whenLine(item: NextUpItem, now: Long): String {
    val start = item.startsAt ?: return "Date to be announced"
    if (now >= start) return "Happening now"
    val days = dayOf(start) - dayOf(now)
    val time = item.time ?: ""
    return when {
      days <= 0L -> if (time.isEmpty()) "Today" else "Today · $time"
      days == 1L -> if (time.isEmpty()) "Tomorrow" else "Tomorrow · $time"
      else -> "In $days days"
    }
  }

  /**
   * When the widget next looks different on its own: the next midnight in India, or an event
   * starting or ending before then.
   */
  fun nextChange(data: NextUpData, now: Long): Long? {
    if (data.state != NextUpData.UPCOMING || data.items.isEmpty()) return null
    var next = nextMidnight(now)
    for (item in data.items) {
      for (moment in listOfNotNull(item.startsAt, item.endsAt)) {
        if (moment in (now + 1) until next) next = moment
      }
    }
    return next
  }
}
