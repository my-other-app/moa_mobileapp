package app.myotherapp.com.eventday

import java.net.URI

/**
 * The event-day card as Dart sends it (EventDayCard.toChannel in
 * lib/features/home_widget/domain/event_day.dart): the event's name, venue, start, end, its time
 * of day in India, and the ticket's page in the app. Never the ticket's code.
 *
 * Plain Kotlin, so its rules can be checked off the phone.
 */
data class EventDayCard(
    val eventId: Long,
    val name: String,
    val place: String?,
    /** Epoch milliseconds. */
    val startsAt: Long,
    val endsAt: Long,
    /** "9:30 am", in India. */
    val time: String,
    /** "Show ticket": `https://myotherapp.in/events/{id}/ticket`. */
    val link: String,
) {
  enum class Phase {
    /** Before the start: the countdown. */
    SOON,
    /** Between the start and the end: "Happening now". */
    NOW,
    /** After the end: the card goes. */
    OVER,
  }

  fun phaseAt(now: Long): Phase =
      when {
        now >= endsAt -> Phase.OVER
        now >= startsAt -> Phase.NOW
        else -> Phase.SOON
      }

  /** The line under the name: "Starts at 9:30 am · Le Méridien" / "Happening now · …". */
  fun lineAt(now: Long, endsTime: String): String {
    val first =
        when (phaseAt(now)) {
          Phase.SOON -> if (time.isEmpty()) "Starts soon" else "Starts at $time"
          else -> if (endsTime.isEmpty()) "Happening now" else "Happening now · until $endsTime"
        }
    return listOfNotNull(first, place?.ifBlank { null }).joinToString(" · ")
  }

  companion object {
    /** A card from the channel's map; null for anything else (or a link off the website). */
    fun from(arguments: Any?): EventDayCard? {
      val map = arguments as? Map<*, *> ?: return null
      val id = (map["event_id"] as? Number)?.toLong() ?: return null
      val name = (map["name"] as? String)?.trim().orEmpty()
      val start = (map["starts_at"] as? Number)?.toLong() ?: return null
      val end = (map["ends_at"] as? Number)?.toLong() ?: return null
      val link = map["link"] as? String ?: return null
      if (id <= 0 || name.isEmpty() || end <= start || !isSiteLink(link)) return null
      return EventDayCard(
          eventId = id,
          name = name,
          place = (map["place"] as? String)?.trim()?.ifEmpty { null },
          startsAt = start,
          endsAt = end,
          time = (map["time"] as? String).orEmpty(),
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
