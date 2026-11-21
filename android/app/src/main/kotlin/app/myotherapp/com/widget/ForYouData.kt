package app.myotherapp.com.widget

import java.net.URI
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.TimeZone
import org.json.JSONArray
import org.json.JSONObject

/**
 * What the "For you" events widget lists (docs/HOME_WIDGETS.md): one JSON string under [DATA_KEY]
 * in home_widget's SharedPreferences, written by the app (lib/features/home_widget/domain/
 * events_for_you.dart) and, while the app is closed, by [ForYouRefreshWorker] after it asks the
 * public front page again.
 *
 * Everything in it is public: the events, the public API's address, the city and its point, the
 * ids of the person's topics. No sign-in token, nothing about a ticket.
 */
data class ForYouData(
    val header: String?,
    val items: List<ForYouItem>,
    val ask: ForYouAsk,
    /** When the events were read (epoch ms); 0 for never. */
    val fetchedAt: Long,
    /** The front page's ETag, for asking again with If-None-Match. */
    val etag: String?,
) {
  /** The events not over at [now], at most [limit]: the widget's rows. */
  fun upcomingAt(now: Long, limit: Int): List<ForYouItem> =
      items.filter { !it.isOverAt(now) }.take(limit)

  /** Whether the widget should ask the front page again at [now]. */
  fun isDueAt(now: Long): Boolean = fetchedAt <= 0 || now - fetchedAt >= REFRESH_EVERY_MS

  fun toJson(): String {
    val root = JSONObject()
    root.put("v", 1)
    root.put("state", if (items.isEmpty()) "empty" else "events")
    header?.let { root.put("header", it) }
    root.put("items", JSONArray().apply { items.forEach { put(it.toJson()) } })
    root.put("see_all", SEE_ALL_LINK)
    root.put("ask", ask.toJson())
    root.put("fetched_at", fetchedAt)
    etag?.let { root.put("etag", it) }
    return root.toString()
  }

  companion object {
    /** The key the app keeps the JSON under (ForYouKind.dataKey). */
    const val DATA_KEY = "events_for_you"

    /** Find events (the website's /events, the app's events directory). */
    const val SEE_ALL_LINK = "https://myotherapp.in/events"

    /** The public API, when the app hasn't said (a widget placed before the app was opened). */
    const val DEFAULT_API = "https://api.myotherapp.in/api/v1"

    /** Asked again this long after the last read. */
    const val REFRESH_EVERY_MS = 3 * 60 * 60 * 1000L

    const val MEDIUM_ROWS = 2
    const val LARGE_ROWS = 4

    /** Nothing read yet: the widget asks at once. */
    val unread = ForYouData(null, emptyList(), ForYouAsk(DEFAULT_API), 0L, null)

    fun parse(json: String?): ForYouData {
      if (json.isNullOrBlank()) return unread
      return try {
        val root = JSONObject(json)
        if (root.optInt("v") != 1) return unread
        val list = root.optJSONArray("items")
        val items = mutableListOf<ForYouItem>()
        if (list != null) {
          for (i in 0 until list.length()) {
            list.optJSONObject(i)?.let { ForYouItem.from(it) }?.let { items.add(it) }
          }
        }
        ForYouData(
            header = root.optString("header").ifBlank { null },
            items = items,
            ask = ForYouAsk.from(root.optJSONObject("ask")),
            fetchedAt = root.optLong("fetched_at", 0L),
            etag = root.optString("etag").ifBlank { null },
        )
      } catch (e: Exception) {
        unread
      }
    }
  }
}

data class ForYouItem(
    val id: Long,
    val name: String,
    /** Epoch milliseconds. */
    val startsAt: Long,
    val endsAt: Long?,
    /** In India time: "SAT", "28", "NOV", "9:30 am", "Sat, 28 Nov". */
    val weekday: String,
    val day: String,
    val month: String,
    val time: String,
    val date: String,
    val club: String?,
    /** The venue, or "Online". */
    val place: String?,
    /** The event's page: https on the website only. */
    val link: String,
) {
  fun isOverAt(now: Long): Boolean = now >= (endsAt ?: startsAt)

  /** "6:00 pm · Kochi Coders · Maker Space, Kochi". */
  val details: String
    get() = listOfNotNull(time.ifEmpty { null }, club, place).joinToString(" · ")

  fun toJson(): JSONObject =
      JSONObject().apply {
        put("id", id)
        put("name", name)
        put("starts_at", startsAt)
        endsAt?.let { put("ends_at", it) }
        put("weekday", weekday)
        put("day", day)
        put("month", month)
        put("time", time)
        put("date", date)
        club?.let { put("club", it) }
        place?.let { put("place", it) }
        put("link", link)
      }

  companion object {
    fun from(json: JSONObject): ForYouItem? {
      val name = json.optString("name").trim()
      val link = json.optString("link").trim()
      if (name.isEmpty() || !isSiteLink(link) || !json.has("starts_at") || !json.has("id")) {
        return null
      }
      fun text(key: String): String? = json.optString(key).trim().ifEmpty { null }
      return ForYouItem(
          id = json.optLong("id"),
          name = name,
          startsAt = json.optLong("starts_at"),
          endsAt = if (json.has("ends_at")) json.optLong("ends_at") else null,
          weekday = json.optString("weekday"),
          day = json.optString("day"),
          month = json.optString("month"),
          time = json.optString("time"),
          date = json.optString("date"),
          club = text("club"),
          place = text("place"),
          link = link,
      )
    }

    fun isSiteLink(link: String): Boolean =
        try {
          val uri = URI(link)
          uri.scheme == "https" && uri.host == "myotherapp.in"
        } catch (e: Exception) {
          false
        }
  }
}

/** Where the widget asks the front page again: the public API, the city's point, the topics. */
data class ForYouAsk(
    val api: String,
    val topics: List<Int> = emptyList(),
    val city: String? = null,
    val lat: Double? = null,
    val lng: Double? = null,
) {
  fun toJson(): JSONObject =
      JSONObject().apply {
        put("api", api)
        put("topics", JSONArray().apply { topics.forEach { put(it) } })
        city?.let { put("city", it) }
        if (lat != null && lng != null) {
          put("lat", lat)
          put("lng", lng)
        }
      }

  /** `GET {api}/discover/home?lat&lng`: only over https; null otherwise. */
  fun homeUrl(): String? {
    val base = api.trimEnd('/')
    val uri = try {
      URI(base)
    } catch (e: Exception) {
      return null
    }
    if (uri.scheme != "https" || uri.host.isNullOrEmpty()) return null
    val query = if (lat != null && lng != null) "?lat=$lat&lng=$lng" else ""
    return "$base/discover/home$query"
  }

  companion object {
    fun from(json: JSONObject?): ForYouAsk {
      if (json == null) return ForYouAsk(ForYouData.DEFAULT_API)
      val topics = mutableListOf<Int>()
      json.optJSONArray("topics")?.let { list ->
        for (i in 0 until list.length()) topics.add(list.optInt(i))
      }
      return ForYouAsk(
          api = json.optString("api").ifBlank { ForYouData.DEFAULT_API },
          topics = topics,
          city = json.optString("city").ifBlank { null },
          lat = if (json.has("lat")) json.optDouble("lat") else null,
          lng = if (json.has("lng")) json.optDouble("lng") else null,
      )
    }
  }
}

/** An event card of the front page, as the widget picks from them. */
data class ForYouCard(
    val id: Long,
    val name: String,
    val ref: String,
    val startsAt: Long,
    val endsAt: Long?,
    val club: String?,
    val place: String?,
    val topics: Set<Int>,
    val distanceKm: Double?,
    val isOnline: Boolean,
) {
  fun isOverAt(now: Long): Boolean = now >= (endsAt ?: startsAt)

  fun isThisWeekAt(now: Long): Boolean = startsAt < now + WEEK_MS

  fun isMine(mine: List<Int>): Boolean = mine.any { it in topics }

  /** In person, within the server's "near" of the place asked about. */
  val isNear: Boolean
    get() = !isOnline && distanceKm != null && distanceKm <= NEAR_KM

  /** The row the widget shows, in India time. */
  fun item(): ForYouItem {
    return ForYouItem(
        id = id,
        name = name,
        startsAt = startsAt,
        endsAt = endsAt,
        weekday = india("EEE", startsAt).uppercase(Locale.ENGLISH),
        day = india("d", startsAt),
        month = india("MMM", startsAt).uppercase(Locale.ENGLISH),
        time = india("h:mm a", startsAt).lowercase(Locale.ENGLISH),
        date = india("EEE, d MMM", startsAt),
        club = club,
        place = place,
        link = "https://myotherapp.in/events/" + encode(ref),
    )
  }

  companion object {
    const val NEAR_KM = 50.0
    const val WEEK_MS = 7 * 24 * 60 * 60 * 1000L
    private const val NAME_LIMIT = 90

    fun from(json: JSONObject): ForYouCard? {
      if (!json.has("id") || json.isNull("id")) return null
      val start = millis(json.optString("starts_at")) ?: return null
      val id = json.optLong("id")
      val rawName = oneLine(if (json.isNull("name")) "" else json.optString("name"))
      val named = rawName.ifEmpty { "Untitled event" }
      val slug = if (json.isNull("slug")) "" else json.optString("slug").trim()
      val online = json.optBoolean("is_online", false)
      val venue = if (json.isNull("location_name")) "" else json.optString("location_name").trim()
      val club = json.optJSONObject("club")?.let { if (it.isNull("name")) "" else it.optString("name").trim() }
      val topics = mutableSetOf<Int>()
      json.optJSONArray("topics")?.let { list ->
        for (i in 0 until list.length()) {
          list.optJSONObject(i)?.let { if (it.has("id")) topics.add(it.optInt("id")) }
        }
      }
      return ForYouCard(
          id = id,
          name = named.take(NAME_LIMIT).trimEnd(),
          ref = slug.ifEmpty { "$id" },
          startsAt = start,
          endsAt = if (json.isNull("ends_at")) null else millis(json.optString("ends_at")),
          club = club?.ifEmpty { null },
          place = if (online) "Online" else venue.ifEmpty { null },
          topics = topics,
          distanceKm =
              if (json.isNull("distance_km")) null
              else json.optDouble("distance_km").takeIf { !it.isNaN() && !it.isInfinite() },
          isOnline = online,
      )
    }

    /** [text] as one part of a path: what Dart's `Uri.encodeComponent` leaves is left. */
    fun encode(text: String): String {
      val out = StringBuilder()
      for (byte in text.toByteArray(Charsets.UTF_8)) {
        val c = byte.toInt() and 0xFF
        val ch = c.toChar()
        if (c < 0x80 && (ch.isLetterOrDigit() || ch in "-_.!~*'()")) {
          out.append(ch)
        } else {
          out.append('%').append(String.format(Locale.ENGLISH, "%02X", c))
        }
      }
      return out.toString()
    }

    fun oneLine(text: String): String = text.trim().split(Regex("\\s+")).filter { it.isNotEmpty() }.joinToString(" ")

    /** [millis] in India (UTC+05:30 all year), in English: "Sat", "28", "Nov", "9:30 AM". */
    fun india(pattern: String, millis: Long): String {
      val format = SimpleDateFormat(pattern, Locale.ENGLISH)
      format.timeZone = TimeZone.getTimeZone("GMT+05:30")
      return format.format(millis)
    }

    private val ISO =
        Regex(
            "^(\\d{4})-(\\d{2})-(\\d{2})[T ](\\d{2}):(\\d{2})(?::(\\d{2})(?:\\.(\\d+))?)?(Z|[+-]\\d{2}:?\\d{2})?$")

    /**
     * An ISO 8601 time as the server writes it ("2026-11-28T04:00:00+00:00", with or without
     * fractions of a second), in epoch milliseconds.
     */
    fun millis(text: String?): Long? {
      val match = ISO.matchEntire(text?.trim() ?: return null) ?: return null
      val g = match.groupValues
      val calendar = Calendar.getInstance(TimeZone.getTimeZone("UTC"), Locale.ENGLISH)
      calendar.clear()
      calendar.set(g[1].toInt(), g[2].toInt() - 1, g[3].toInt(), g[4].toInt(), g[5].toInt(),
          g[6].ifEmpty { "0" }.toInt())
      var ms = calendar.timeInMillis
      if (g[7].isNotEmpty()) ms += (g[7] + "000").take(3).toLong()
      val zone = g[8]
      if (zone.isNotEmpty() && zone != "Z") {
        val sign = if (zone.startsWith("-")) -1 else 1
        val digits = zone.drop(1).replace(":", "")
        val minutes = digits.take(2).toLong() * 60 + digits.takeLast(2).toLong()
        ms -= sign * minutes * 60 * 1000
      }
      return ms
    }
  }
}

/**
 * The widget's rules for what to list: the same as `pickForYou` in
 * lib/features/home_widget/domain/events_for_you.dart and ForYouPicker in ForYouData.swift.
 */
object ForYouPicker {
  const val LIMIT = 6
  const val SHOWN = ForYouData.LARGE_ROWS

  data class Lists(val thisWeek: List<ForYouCard>, val near: List<ForYouCard>, val popular: List<ForYouCard>)

  /** The front page's three lists: `this_week`, `near` (only when placed) and `popular`. */
  fun lists(home: JSONObject): Lists {
    fun cards(key: String): List<ForYouCard> {
      val list = home.optJSONArray(key) ?: return emptyList()
      return (0 until list.length()).mapNotNull { list.optJSONObject(it)?.let(ForYouCard::from) }
    }
    val where = home.optJSONObject("where")
    val placed =
        where != null && !where.isNull("lat") && !where.isNull("lng") &&
            !where.isNull("source") && where.optString("source") != "none"
    return Lists(cards("this_week"), if (placed) cards("near").filter { it.isNear } else emptyList(), cards("popular"))
  }

  data class Pick(val header: String?, val items: List<ForYouItem>)

  fun pick(
      thisWeek: List<ForYouCard>,
      near: List<ForYouCard>,
      popular: List<ForYouCard>,
      topics: List<Int>,
      now: Long,
  ): Pick {
    val seen = mutableSetOf<Long>()
    val week = (thisWeek + near).filter { !it.isOverAt(now) && it.isThisWeekAt(now) && seen.add(it.id) }
    // Date order; the server's order among equals (sortedBy is stable).
    val byDate = week.sortedBy { it.startsAt }
    fun rank(card: ForYouCard) = if (card.isMine(topics)) 0 else if (card.isNear) 1 else 2
    val weekOrdered = listOf(0, 1, 2).flatMap { r -> byDate.filter { rank(it) == r } }
    val more = popular.filter { !it.isOverAt(now) && seen.add(it.id) }
    val popularOrdered = more.filter { it.isMine(topics) } + more.filter { !it.isMine(topics) }
    val picked = (weekOrdered + popularOrdered).take(LIMIT)
    if (picked.isEmpty()) return Pick(null, emptyList())
    return Pick(header(picked.take(SHOWN), topics, now), picked.map { it.item() })
  }

  fun header(first: List<ForYouCard>, topics: List<Int>, now: Long): String =
      when {
        first.any { it.isMine(topics) } -> "For you"
        first.any { it.isNear && it.isThisWeekAt(now) } -> "This week near you"
        first.any { it.isThisWeekAt(now) } -> "This week"
        else -> "Popular"
      }

  /** What [data] becomes once the front page [body] is read at [now]. */
  fun picked(body: String, data: ForYouData, now: Long, etag: String?): ForYouData? {
    val home = try {
      JSONObject(body)
    } catch (e: Exception) {
      return null
    }
    val lists = lists(home)
    val result = pick(lists.thisWeek, lists.near, lists.popular, data.ask.topics, now)
    return ForYouData(result.header, result.items, data.ask, now, etag)
  }
}
