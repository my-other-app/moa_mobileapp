package app.myotherapp.com.widget

import android.net.Uri
import org.json.JSONObject

/**
 * What the "Networking" widget shows, as the app wrote it
 * (lib/features/home_widget/domain/networking.dart, docs/HOME_WIDGETS.md): one JSON string under
 * [DATA_KEY] in home_widget's SharedPreferences.
 *
 * Only what the widget shows and where a tap goes: the person's name, the public profile link their
 * QR encodes, the size of their network, and the taps' links. Never a ticket, a token, an email or
 * a phone number.
 */
data class NetworkingData(
    val state: String,
    val name: String?,
    val profileLink: String?,
    val network: Int?,
    val qrLink: String,
    val scanLink: String,
    val networkLink: String,
) {
  val signedIn: Boolean
    get() = state != SIGNED_OUT

  /** What the QR encodes, when there is a code to draw: only the website's https links. */
  val qrPayload: String?
    get() = if (state == READY) profileLink?.takeIf { isSiteLink(it) } else null

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
        NetworkingData(
            state = root.optString("state", SIGNED_OUT),
            name = root.optString("name").trim().ifBlank { null },
            profileLink = root.optString("profile_link").trim().ifBlank { null },
            network = if (root.has("network")) root.optInt("network", -1).takeIf { it >= 0 } else null,
            qrLink = link("qr", MY_QR_LINK),
            scanLink = link("scan", SCAN_LINK),
            networkLink = link("network", NETWORK_LINK),
        )
      } catch (e: Exception) {
        signedOut
      }
    }
  }
}
