package app.myotherapp.com.tiles

import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.util.Log
import app.myotherapp.com.MainActivity
import app.myotherapp.com.R

/**
 * The app's Quick Settings tiles (docs/HOME_WIDGETS.md): **Scan** and **My QR**. People add them
 * themselves -- swipe down twice, the pencil (Edit), then drag "Scan" or "My QR" (MyOtherApp) into
 * the tiles; the app never asks.
 *
 * A tap opens the app on its page exactly as a widget's tap or an icon shortcut does: an intent to
 * [MainActivity] carrying the website's address (`https://myotherapp.in/network/scan`,
 * `/profile/qr`), which Flutter's deep linking hands to the app's router, which reads it as its own
 * page -- signing in first where the page needs an account. On a locked phone the phone unlocks
 * first: My QR never shows over the lock screen.
 */
abstract class PageTileService : TileService() {
  /** The page this tile opens (a `_link` string in res/values/app_shortcuts.xml). */
  protected abstract val linkRes: Int

  /** Its words under the tile (Android 10+): the app's name, so "Scan" says whose. */
  override fun onStartListening() {
    super.onStartListening()
    val tile = qsTile ?: return
    // A button, not a switch: drawn as one that is off.
    tile.state = Tile.STATE_INACTIVE
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
      tile.subtitle = getString(R.string.tile_subtitle)
    }
    tile.updateTile()
  }

  override fun onClick() {
    super.onClick()
    val link = getString(linkRes)
    if (isLocked) {
      unlockAndRun { open(link) }
    } else {
      open(link)
    }
  }

  /** Opens [link] in the app and closes the shade. */
  @SuppressLint("StartActivityAndCollapseDeprecated")
  private fun open(link: String) {
    val intent = PageTiles.intentFor(this, link)
    try {
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
        // Android 14 takes a PendingIntent here (an Intent throws for apps that target it).
        startActivityAndCollapse(
            PendingIntent.getActivity(
                this,
                linkRes,
                intent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            ))
      } else {
        @Suppress("DEPRECATION") startActivityAndCollapse(intent)
      }
    } catch (e: Exception) {
      Log.w("PageTileService", "could not open the page", e)
    }
  }
}

/** "Scan": the scanner that saves a person. */
class ScanTileService : PageTileService() {
  override val linkRes = R.string.shortcut_scan_link
}

/** "My QR": the person's QR code, full screen. */
class MyQrTileService : PageTileService() {
  override val linkRes = R.string.shortcut_my_qr_link
}

object PageTiles {
  private const val SITE_HOST = "myotherapp.in"

  /** Only the website's https addresses are ever opened. */
  fun isSiteLink(link: String): Boolean =
      try {
        val uri = Uri.parse(link)
        uri.scheme == "https" && uri.host == SITE_HOST
      } catch (e: Exception) {
        false
      }

  /**
   * Opens [link] in the running app, or starts it with it: a new task from the shade, brought to
   * the front (single top) so [MainActivity] gets the link as a new intent and Flutter pushes it to
   * the router -- the icon shortcuts' intent (AppShortcuts.kt).
   */
  fun intentFor(context: Context, link: String): Intent {
    val safe = if (isSiteLink(link)) link else "https://$SITE_HOST/"
    return Intent(context, MainActivity::class.java)
        .setAction(Intent.ACTION_VIEW)
        .setData(Uri.parse(safe))
        .addFlags(
            Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP)
  }
}
