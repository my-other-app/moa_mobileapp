package app.myotherapp.com.eventday

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** The event-day card's rules (EventDayCard.kt): what it is given, and where it stands. */
class EventDayCardTest {
  private val start = 1_795_838_400_000L // 9:30 am, 28 Nov 2026, India
  private val end = start + 8 * 3600 * 1000L

  private fun map(vararg changes: Pair<String, Any?>): Map<String, Any?> =
      mapOf(
          "event_id" to 7,
          "name" to "DevFest Kochi",
          "place" to "Le Méridien, Kochi",
          "starts_at" to start,
          "ends_at" to end,
          "time" to "9:30 am",
          "date" to "Sat, 28 Nov",
          "link" to "https://myotherapp.in/events/7/ticket",
      ) + changes

  @Test
  fun readsTheCardDartSends() {
    val card = EventDayCard.from(map())!!
    assertEquals(7L, card.eventId)
    assertEquals("Le Méridien, Kochi", card.place)
    assertEquals("https://myotherapp.in/events/7/ticket", card.link)
  }

  @Test
  fun refusesAnythingElse() {
    assertNull(EventDayCard.from("a card"))
    assertNull(EventDayCard.from(map("link" to "https://evil.example/t")))
    assertNull(EventDayCard.from(map("link" to "http://myotherapp.in/events/7/ticket")))
    assertNull(EventDayCard.from(map("ends_at" to start)))
    assertNull(EventDayCard.from(map("event_id" to 0)))
    assertNull(EventDayCard.from(map("name" to " ")))
  }

  @Test
  fun phases() {
    val card = EventDayCard.from(map())!!
    assertEquals(EventDayCard.Phase.SOON, card.phaseAt(start - 1))
    assertEquals(EventDayCard.Phase.NOW, card.phaseAt(start))
    assertEquals(EventDayCard.Phase.OVER, card.phaseAt(end))
  }

  @Test
  fun theLineUnderTheName() {
    val card = EventDayCard.from(map())!!
    assertEquals("Starts at 9:30 am · Le Méridien, Kochi", card.lineAt(start - 60_000, "5:30 pm"))
    assertEquals(
        "Happening now · until 5:30 pm · Le Méridien, Kochi", card.lineAt(start + 60_000, "5:30 pm"))
    val online = EventDayCard.from(map("place" to null))!!
    assertEquals("Starts at 9:30 am", online.lineAt(start - 60_000, "5:30 pm"))
  }
}
