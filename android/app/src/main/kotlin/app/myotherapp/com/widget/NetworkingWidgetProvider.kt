package app.myotherapp.com.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews
import app.myotherapp.com.MainActivity
import app.myotherapp.com.R
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * "Networking", the home-screen widget (docs/HOME_WIDGETS.md): the person's QR code to share, and
 * a quick way to scan someone.
 *
 * Small (2x2): the code, large enough to scan, with the name under it. Medium (from about 4 cells
 * wide): the code on the left; the name, "Scan to save me", a Scan pill and "Network · 12" on the
 * right. Large (about 4x4): the medium on top, then "Recently met" -- three people (four on a taller
 * widget), each with their initials in a circle of their own colour or, when the person turned photos
 * on, their photo; their name and where they met; each opening their page -- and "3 without a note
 * yet ›". The code and the card open My QR full screen, Scan the scanner that saves a person,
 * "Network" the Network tab -- each the website's address, which the app's router reads as its
 * own page (Flutter deep linking), signing in first when needed. Signed out: "Sign in to share
 * your QR". No code read yet: a calm placeholder that opens My QR, which makes it.
 *
 * The code is drawn here from the stored link (QrBitmap), dark on white in both themes. Home
 * screen only (`widgetCategory`): never on a lock screen.
 */
class NetworkingWidgetProvider : HomeWidgetProvider() {

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    val data = NetworkingData.parse(widgetData.getString(NetworkingData.DATA_KEY, null))
    val drawn = Drawn(data, widgetData, context)
    for (id in appWidgetIds) {
      appWidgetManager.updateAppWidget(id, views(context, appWidgetManager, id, drawn))
    }
  }

  /** What every size draws from: the data, its code and "Recently met"'s photos, made once. */
  private class Drawn(val data: NetworkingData, widgetData: SharedPreferences, context: Context) {
    val qr: Bitmap? = data.qrPayload?.let { QrBitmap.tile(it) }
    val photos: Map<String, Bitmap> =
        if (data.signedIn) WidgetPhotos.load(context, widgetData, data.recentlyMet()) else emptyMap()
  }

  override fun onAppWidgetOptionsChanged(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetId: Int,
      newOptions: Bundle,
  ) {
    super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
    // Resized: below Android 12 the layout for the new size is chosen here.
    val widgetData = HomeWidgetPlugin.getData(context)
    val data = NetworkingData.parse(widgetData.getString(NetworkingData.DATA_KEY, null))
    appWidgetManager.updateAppWidget(
        appWidgetId,
        views(context, appWidgetManager, appWidgetId, Drawn(data, widgetData, context)))
  }

  private fun views(
      context: Context,
      manager: AppWidgetManager,
      id: Int,
      drawn: Drawn,
  ): RemoteViews {
    val data = drawn.data
    val qr = drawn.qr
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
      // The launcher picks the largest that fits, and switches as it is resized. All share the
      // one bitmap of the code (and the large ones the photos).
      return RemoteViews(
          mapOf(
              SizeF(SMALL_MIN_DP, 80f) to render(context, false, data, qr),
              SizeF(MEDIUM_MIN_DP, 80f) to render(context, true, data, qr),
              SizeF(MEDIUM_MIN_DP, LARGE_MIN_HEIGHT_DP) to
                  renderLarge(context, drawn, LARGE_ROWS),
              SizeF(MEDIUM_MIN_DP, TALL_MIN_HEIGHT_DP) to
                  renderLarge(context, drawn, NetworkingData.MET_LIMIT),
          ))
    }
    // Below Android 12: the width picks small or medium, and the height (in portrait, the widget's
    // tallest) large.
    val options = manager.getAppWidgetOptions(id)
    val width = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
    val height = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT)
    if (width >= MEDIUM_MIN_DP && height >= LARGE_MIN_HEIGHT_DP) {
      val rows = if (height >= TALL_MIN_HEIGHT_DP) NetworkingData.MET_LIMIT else LARGE_ROWS
      return renderLarge(context, drawn, rows)
    }
    return render(context, width >= MEDIUM_MIN_DP, data, qr)
  }

  /**
   * Large: the medium's top, then "Recently met" -- [rows] people at most -- and the notes still to
   * write. Signed out: the top alone, asking the person to sign in.
   */
  private fun renderLarge(context: Context, drawn: Drawn, rows: Int): RemoteViews {
    val data = drawn.data
    val views = RemoteViews(context.packageName, R.layout.widget_networking_large)
    views.setOnClickPendingIntent(R.id.networking_root, open(context, data.qrLink))
    val hasQr = drawn.qr != null
    if (hasQr) {
      views.setImageViewBitmap(R.id.networking_qr, drawn.qr)
      views.setViewVisibility(R.id.networking_qr, View.VISIBLE)
      views.setViewVisibility(R.id.networking_placeholder, View.GONE)
    } else {
      views.setViewVisibility(R.id.networking_qr, View.GONE)
      views.setViewVisibility(R.id.networking_placeholder, View.VISIBLE)
    }
    fillMedium(context, views, data, hasQr)
    if (!data.signedIn) {
      views.setViewVisibility(R.id.networking_met, View.GONE)
      return views
    }
    views.setViewVisibility(R.id.networking_met, View.VISIBLE)

    val people = data.recentlyMet(rows)
    views.setViewVisibility(R.id.networking_met_empty, if (people.isEmpty()) View.VISIBLE else View.GONE)
    views.setTextViewText(
        R.id.networking_met_empty,
        context.getString(
            if (data.met == null) R.string.networking_met_unknown else R.string.networking_met_empty))
    for (row in MET_ROW_IDS.indices) {
      val ids = MET_ROW_IDS[row]
      val person = people.getOrNull(row)
      // Rows beyond what fits are gone; rows with nobody keep their place.
      views.setViewVisibility(
          ids.row,
          when {
            row >= rows -> View.GONE
            person == null -> if (people.isEmpty()) View.GONE else View.INVISIBLE
            else -> View.VISIBLE
          })
      if (person == null) continue
      val photo = person.photo?.let { drawn.photos[it] }
      if (photo != null) {
        views.setImageViewBitmap(ids.photo, photo)
        views.setViewVisibility(ids.photo, View.VISIBLE)
        views.setViewVisibility(ids.initials, View.GONE)
      } else {
        views.setViewVisibility(ids.photo, View.GONE)
        views.setViewVisibility(ids.initials, View.VISIBLE)
        views.setTextViewText(ids.initials, person.initials)
        views.setInt(ids.initials, "setBackgroundResource", CIRCLES[person.colour])
        // The letters are the same in both themes; only the circle changes.
        views.setTextColor(ids.initials, CIRCLE_INKS[person.colour])
      }
      views.setTextViewText(ids.name, person.name)
      views.setViewVisibility(ids.event, if (person.event == null) View.GONE else View.VISIBLE)
      views.setTextViewText(ids.event, person.event ?: "")
      views.setContentDescription(
          ids.row, listOfNotNull(person.name, person.event).joinToString(", "))
      views.setOnClickPendingIntent(ids.row, open(context, person.link))
    }

    val noNote = data.noNote ?: 0
    if (noNote > 0) {
      views.setViewVisibility(R.id.networking_no_note, View.VISIBLE)
      views.setTextViewText(
          R.id.networking_no_note, context.getString(R.string.networking_no_note, noNote))
      views.setOnClickPendingIntent(R.id.networking_no_note, open(context, data.networkLink))
    } else {
      views.setViewVisibility(R.id.networking_no_note, View.GONE)
    }
    return views
  }

  private fun open(context: Context, link: String): PendingIntent =
      HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse(link))

  private fun render(
      context: Context,
      medium: Boolean,
      data: NetworkingData,
      qr: Bitmap?,
  ): RemoteViews {
    val views =
        RemoteViews(
            context.packageName,
            if (medium) R.layout.widget_networking_medium else R.layout.widget_networking_small,
        )
    // The card (and the code on it) opens My QR; signed out, sign-in comes first.
    views.setOnClickPendingIntent(R.id.networking_root, open(context, data.qrLink))

    // The code, or the placeholder.
    if (qr != null) {
      views.setImageViewBitmap(R.id.networking_qr, qr)
      views.setViewVisibility(R.id.networking_qr, View.VISIBLE)
      views.setViewVisibility(R.id.networking_placeholder, View.GONE)
    } else {
      views.setViewVisibility(R.id.networking_qr, View.GONE)
      views.setViewVisibility(R.id.networking_placeholder, View.VISIBLE)
    }

    if (!medium) {
      fillSmall(context, views, data, qr != null)
    } else {
      fillMedium(context, views, data, qr != null)
    }
    return views
  }

  private fun fillSmall(context: Context, views: RemoteViews, data: NetworkingData, hasQr: Boolean) {
    if (!data.signedIn) {
      views.setViewVisibility(R.id.networking_content, View.GONE)
      views.setViewVisibility(R.id.networking_message, View.VISIBLE)
      return
    }
    views.setViewVisibility(R.id.networking_message, View.GONE)
    views.setViewVisibility(R.id.networking_content, View.VISIBLE)
    // Under the code, the name; under the placeholder, "Tap for your QR" (its own view, so each
    // keeps its colour from the layout when the phone's theme changes).
    views.setViewVisibility(R.id.networking_name, if (hasQr) View.VISIBLE else View.GONE)
    views.setViewVisibility(R.id.networking_hint, if (hasQr) View.GONE else View.VISIBLE)
    views.setTextViewText(
        R.id.networking_name, data.name ?: context.getString(R.string.networking_my_qr))
  }

  private fun fillMedium(context: Context, views: RemoteViews, data: NetworkingData, hasQr: Boolean) {
    if (!data.signedIn) {
      views.setTextViewText(R.id.networking_name, context.getString(R.string.networking_signed_out))
      views.setViewVisibility(R.id.networking_subtitle, View.GONE)
      views.setTextViewText(R.id.networking_scan, context.getString(R.string.networking_sign_in))
      views.setTextViewCompoundDrawablesRelative(R.id.networking_scan, 0, 0, 0, 0)
      views.setOnClickPendingIntent(R.id.networking_scan, open(context, data.qrLink))
      views.setViewVisibility(R.id.networking_network, View.GONE)
      return
    }
    views.setTextViewText(
        R.id.networking_name, data.name ?: context.getString(R.string.networking_my_qr))
    views.setViewVisibility(R.id.networking_subtitle, View.VISIBLE)
    views.setTextViewText(
        R.id.networking_subtitle,
        context.getString(
            if (hasQr) R.string.networking_scan_to_save else R.string.networking_get_code),
    )
    views.setTextViewText(R.id.networking_scan, context.getString(R.string.networking_scan))
    views.setOnClickPendingIntent(R.id.networking_scan, open(context, data.scanLink))
    views.setViewVisibility(R.id.networking_network, View.VISIBLE)
    views.setTextViewText(
        R.id.networking_network,
        data.network?.let { context.getString(R.string.networking_network_count, it) }
            ?: context.getString(R.string.networking_network),
    )
    views.setOnClickPendingIntent(R.id.networking_network, open(context, data.networkLink))
  }

  /** One "Recently met" row's views. */
  private class MetRowIds(
      val row: Int,
      val initials: Int,
      val photo: Int,
      val name: Int,
      val event: Int,
  )

  companion object {
    /** Widths (dp) from which each size is used: a 2-cell widget is about 110 dp wide. */
    private const val SMALL_MIN_DP = 100f
    private const val MEDIUM_MIN_DP = 220f

    /** Heights (dp) from which the large layout is used (about 4 cells), and with four people. */
    private const val LARGE_MIN_HEIGHT_DP = 240f
    private const val TALL_MIN_HEIGHT_DP = 300f

    /** How many people the large layout shows below [TALL_MIN_HEIGHT_DP]. */
    private const val LARGE_ROWS = 3

    /** The circles, by the colour the app gave each person, and the letters on them. */
    private val CIRCLES =
        listOf(
            R.drawable.widget_met_circle_0,
            R.drawable.widget_met_circle_1,
            R.drawable.widget_met_circle_2,
            R.drawable.widget_met_circle_3,
        )
    private val CIRCLE_INKS =
        listOf(Color.WHITE, Color.rgb(0x2C, 0x33, 0x3D), Color.WHITE, Color.rgb(0x2C, 0x33, 0x3D))

    private val MET_ROW_IDS =
        listOf(
            MetRowIds(
                R.id.networking_met_0, R.id.networking_met_0_initials, R.id.networking_met_0_photo,
                R.id.networking_met_0_name, R.id.networking_met_0_event),
            MetRowIds(
                R.id.networking_met_1, R.id.networking_met_1_initials, R.id.networking_met_1_photo,
                R.id.networking_met_1_name, R.id.networking_met_1_event),
            MetRowIds(
                R.id.networking_met_2, R.id.networking_met_2_initials, R.id.networking_met_2_photo,
                R.id.networking_met_2_name, R.id.networking_met_2_event),
            MetRowIds(
                R.id.networking_met_3, R.id.networking_met_3_initials, R.id.networking_met_3_photo,
                R.id.networking_met_3_name, R.id.networking_met_3_event),
        )
  }
}
