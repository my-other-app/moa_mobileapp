package app.myotherapp.com.widget

import android.net.Uri
import org.json.JSONObject

/**
 * What the "Networking" widget shows, as the app wrote it
 * (lib/features/home_widget/domain/networking.dart, docs/HOME_WIDGETS.md): one JSON string under
 * [DATA_KEY] in home_widget's SharedPreferences.
 *
 * Only what the widget shows and where a tap goes: the person's name, the public profile link their
 * QR encodes, the size of their network, the taps' links, and for the large widget's "Recently met"
 * a few people's names, initials, circle colours, where they met, the key of each one's photo (only
 * when the person turned photos on) and how many have no note yet. Never a ticket, a token, an email
 * or a phone number.
 */
data class NetworkingData(
    val state: String,
    val name: String?,
    val profileLink: String?,
    val network: Int?,
    val qrLink: String,
    val scanLink: String,
    val networkLink: String,
    /** "Recently met", last met first; null until the app has read it. */
    val met: List<MetPerson>? = null,
    /** How many of the people the app read have no note yet. */
    val noNote: Int? = null,
) {
  val signedIn: Boolean
    get() = state != SIGNED_OUT

  /** What the QR encodes, when there is a code to draw: only the website's https links. */
  val qrPayload: String?
    get() = if (state == READY) profileLink?.takeIf { isSiteLink(it) } else null

  /** The people "Recently met" shows: the first [limit]. */
  fun recentlyMet(limit: Int = MET_LIMIT): List<MetPerson> = (met ?: emptyList()).take(limit)

  companion object {
    /** The key the app keeps the JSON under (NetworkingKind.dataKey). */
    const val DATA_KEY = "networking"

    const val SIGNED_OUT = "signed_out"
    const val NO_QR = "no_qr"
    const val READY = "ready"

    /** My QR, full screen (signing in first when needed). */
    const val MY_QR_LINK = "https://myotherapp.in/profile/qr"

    /** The scanner that saves a person. */
    const val SCAN_LINK = "https://myotherapp.in/network/scan"

    /** The Network tab. */
    const val NETWORK_LINK = "https://myotherapp.in/network"

    private const val SITE_HOST = "myotherapp.in"

    /** How many people the large widget shows. */
    const val MET_LIMIT = 4

    /** A photo's key, as the app names them: `networking_photo_<id>` (widgetPhotoKey in Dart). */
    const val PHOTO_KEY_PREFIX = "networking_photo_"

    fun isPhotoKey(key: String): Boolean =
        key.length > PHOTO_KEY_PREFIX.length &&
            key.startsWith(PHOTO_KEY_PREFIX) &&
            key.substring(PHOTO_KEY_PREFIX.length).all { it in '0'..'9' }

    /** "Ananya Iyer" -> "AI"; "?" for no name (initialsOf in the app). */
    fun initialsOf(name: String): String {
      val words = name.trim().split(Regex("\\s+")).filter { it.isNotEmpty() }
      if (words.isEmpty()) return "?"
      val first = words.first().codePointAt(0)
      val last = if (words.size > 1) words.last().codePointAt(0) else null
      return buildString {
            appendCodePoint(first)
            if (last != null) appendCodePoint(last)
          }
          .uppercase()
    }

    /** Nothing written yet (the app not opened since install), or a version this build can't read. */
    val signedOut =
        NetworkingData(SIGNED_OUT, null, null, null, MY_QR_LINK, SCAN_LINK, NETWORK_LINK)

    fun isSiteLink(link: String): Boolean =
        try {
          val uri = Uri.parse(link)
          uri.scheme == "https" && uri.host == SITE_HOST
        } catch (e: Exception) {
          false
        }

    fun parse(json: String?): NetworkingData {
      if (json.isNullOrBlank()) return signedOut
      return try {
        val root = JSONObject(json)
        if (root.optInt("v") != 1) return signedOut
        val links = root.optJSONObject("links")
        fun link(key: String, fallback: String): String =
            links?.optString(key)?.takeIf { it.isNotBlank() && isSiteLink(it) } ?: fallback
        val networkLink = link("network", NETWORK_LINK)
        NetworkingData(
            state = root.optString("state", SIGNED_OUT),
            name = root.optString("name").trim().ifBlank { null },
            profileLink = root.optString("profile_link").trim().ifBlank { null },
            network = if (root.has("network")) root.optInt("network", -1).takeIf { it >= 0 } else null,
            qrLink = link("qr", MY_QR_LINK),
            scanLink = link("scan", SCAN_LINK),
            networkLink = networkLink,
            met =
                root.optJSONArray("met")?.let { list ->
                  (0 until list.length()).mapNotNull { i ->
                    list.optJSONObject(i)?.let { MetPerson.from(it, networkLink) }
                  }
                },
            noNote = if (root.has("no_note")) root.optInt("no_note", 0).coerceAtLeast(0) else null,
        )
      } catch (e: Exception) {
        signedOut
      }
    }
  }
}

/** Someone on "Recently met". */
data class MetPerson(
    val name: String,
    val initials: String,
    /** One of the circles' four colours (widget_met_circle_*), from the app. */
    val colour: Int,
    /** The event they last met at. */
    val event: String?,
    /** Their page in the app (`https://myotherapp.in/network/{id}`), else the Network tab. */
    val link: String,
    /** The key the app kept their photo under; none unless photos are on. */
    val photo: String?,
) {
  companion object {
    fun from(json: JSONObject, fallbackLink: String): MetPerson? {
      val name = json.optString("name").trim()
      if (name.isEmpty()) return null
      val link = json.optString("link").trim()
      return MetPerson(
          name = name,
          initials =
              json.optString("initials").trim().take(2).ifEmpty { NetworkingData.initialsOf(name) },
          colour = Math.floorMod(json.optInt("colour", 0), 4),
          event = json.optString("event").trim().ifEmpty { null },
          link = link.takeIf { it.isNotEmpty() && NetworkingData.isSiteLink(it) } ?: fallbackLink,
          photo = json.optString("photo").trim().takeIf { NetworkingData.isPhotoKey(it) },
      )
    }
  }
}
