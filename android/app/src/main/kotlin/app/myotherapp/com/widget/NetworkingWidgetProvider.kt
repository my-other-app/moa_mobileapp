package app.myotherapp.com.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Bitmap
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
 * right. The code and the card open My QR full screen, Scan the scanner that saves a person,
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
    val qr = data.qrPayload?.let { QrBitmap.tile(it) }
    for (id in appWidgetIds) {
      appWidgetManager.updateAppWidget(id, views(context, appWidgetManager, id, data, qr))
    }
  }

  override fun onAppWidgetOptionsChanged(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetId: Int,
      newOptions: Bundle,
  ) {
    super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
    // Resized: below Android 12 the layout for the new size is chosen here.
    val data =
        NetworkingData.parse(
            HomeWidgetPlugin.getData(context).getString(NetworkingData.DATA_KEY, null))
    val qr = data.qrPayload?.let { QrBitmap.tile(it) }
    appWidgetManager.updateAppWidget(
        appWidgetId, views(context, appWidgetManager, appWidgetId, data, qr))
  }

  private fun views(
      context: Context,
      manager: AppWidgetManager,
      id: Int,
      data: NetworkingData,
      qr: Bitmap?,
  ): RemoteViews {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
      // The launcher picks the largest that fits, and switches as it is resized. Both share the
      // one bitmap of the code.
      return RemoteViews(
          mapOf(
              SizeF(SMALL_MIN_DP, 80f) to render(context, false, data, qr),
              SizeF(MEDIUM_MIN_DP, 80f) to render(context, true, data, qr),
          ))
    }
    val width = manager.getAppWidgetOptions(id).getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
    return render(context, width >= MEDIUM_MIN_DP, data, qr)
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

  companion object {
    /** Widths (dp) from which each size is used: a 2-cell widget is about 110 dp wide. */
    private const val SMALL_MIN_DP = 100f
    private const val MEDIUM_MIN_DP = 220f
  }
}
