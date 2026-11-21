package app.myotherapp.com

import android.content.Context
import android.content.Intent
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.drawable.Icon
import android.net.Uri
import android.os.Build
import android.util.Log

/**
 * The app's shortcuts: touch and hold the icon for Scan, My QR, Network and My tickets
 * (docs/HOME_WIDGETS.md). The iPhone's quick actions are the same four (ios/Runner/Info.plist).
 *
 * Each opens the website's address in its `_link` string (res/values/app_shortcuts.xml) the way a
 * widget's tap does: an intent to [MainActivity] carrying the address, which Flutter's deep linking
 * hands to the app's router, which reads it as its own page -- signing in first where the page needs
 * an account, then going on to it.
 *
 * Published as dynamic shortcuts at every launch, not declared in the manifest: a manifest
 * shortcut always clears the app's task (Intent.FLAG_ACTIVITY_CLEAR_TASK) and so restarts the app
 * from its splash screen, while these bring the running app forward and open the page in it.
 * Android 7.1 (API 25) onwards; the app's first launch publishes them.
 */
object AppShortcuts {
  private const val TAG = "AppShortcuts"

  /** The shortcut a launch came from, so the launcher can learn which are used. */
  const val EXTRA_SHORTCUT_ID = "app.myotherapp.in.SHORTCUT_ID"

  private class Shortcut(
      val id: String,
      val shortLabel: Int,
      val longLabel: Int,
      val link: Int,
      val icon: Int,
  )

  private val all =
      listOf(
          Shortcut(
              "scan",
              R.string.shortcut_scan_short,
              R.string.shortcut_scan_long,
              R.string.shortcut_scan_link,
              R.drawable.ic_shortcut_scan,
          ),
          Shortcut(
              "my_qr",
              R.string.shortcut_my_qr_short,
              R.string.shortcut_my_qr_long,
              R.string.shortcut_my_qr_link,
              R.drawable.ic_shortcut_qr,
          ),
          Shortcut(
              "network",
              R.string.shortcut_network_short,
              R.string.shortcut_network_long,
              R.string.shortcut_network_link,
              R.drawable.ic_shortcut_network,
          ),
          Shortcut(
              "my_tickets",
              R.string.shortcut_tickets_short,
              R.string.shortcut_tickets_long,
              R.string.shortcut_tickets_link,
              R.drawable.ic_shortcut_tickets,
          ),
      )

  /** Publish the four, off the main thread (the system may take a moment). Never throws. */
  fun publish(context: Context) {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N_MR1) return
    val app = context.applicationContext
    Thread {
          try {
            val manager = app.getSystemService(ShortcutManager::class.java) ?: return@Thread
            val shortcuts =
                all.mapIndexed { rank, shortcut ->
                  ShortcutInfo.Builder(app, shortcut.id)
                      .setShortLabel(app.getString(shortcut.shortLabel))
                      .setLongLabel(app.getString(shortcut.longLabel))
                      .setIcon(Icon.createWithResource(app, shortcut.icon))
                      .setRank(rank)
                      .setIntent(intentFor(app, shortcut.id, app.getString(shortcut.link)))
                      .build()
                }
            manager.setDynamicShortcuts(shortcuts)
          } catch (e: Exception) {
            // No shortcuts this time (a locked profile, a launcher without them).
            Log.w(TAG, "could not publish the shortcuts", e)
          }
        }
        .start()
  }

  /**
   * Opens [link] in the running app: to [MainActivity] (single top), so it gets the link as a new
   * intent and Flutter pushes it to the router, or starts with it.
   */
  private fun intentFor(context: Context, id: String, link: String): Intent =
      Intent(context, MainActivity::class.java)
          .setAction(Intent.ACTION_VIEW)
          .setData(Uri.parse(link))
          .putExtra(EXTRA_SHORTCUT_ID, id)
          .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)

  /** Tell the launcher a shortcut was used, when [intent] came from one. */
  fun reportUsed(context: Context, intent: Intent?) {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N_MR1) return
    val id = intent?.getStringExtra(EXTRA_SHORTCUT_ID) ?: return
    if (all.none { it.id == id }) return
    try {
      context.getSystemService(ShortcutManager::class.java)?.reportShortcutUsed(id)
    } catch (e: Exception) {
      Log.w(TAG, "could not report a shortcut used", e)
    }
  }
}
