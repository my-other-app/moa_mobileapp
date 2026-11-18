package app.myotherapp.com.widget

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
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
import es.antonborri.home_widget.HomeWidgetScheduler

/**
 * "For you", the events widget (docs/HOME_WIDGETS.md): what is on this week -- the person's topics
 * first, then near them -- then the platform's popular events. Medium (4x2) lists two, large (about
 * 4x4) four; each row (date, name, time · club · place) opens that event's page in the app, "See
 * all" the events directory. Nothing on: a calm "Find events".
 *
 * The app writes the list whenever it reads its front page; while the app is closed
 * [ForYouRefreshWorker] reads the same public page every few hours (WorkManager, on any network).
 * A redraw is booked for the next listed event's end, so an event over drops off.
 */
class ForYouWidgetProvider : HomeWidgetProvider() {

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    val data = ForYouData.parse(widgetData.getString(ForYouData.DATA_KEY, null))
    val now = System.currentTimeMillis()
    for (id in appWidgetIds) {
      appWidgetManager.updateAppWidget(id, views(context, appWidgetManager, id, data, now))
    }
    bookNextRedraw(context, data, now)
    // Kept reading by itself while placed; and at once when what it has is old (placed before
    // the app was opened, after a sign-out, after days offline).
    ForYouRefresh.schedule(context)
    if (data.isDueAt(now)) ForYouRefresh.now(context)
  }

  override fun onAppWidgetOptionsChanged(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetId: Int,
      newOptions: Bundle,
  ) {
    super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
    // Resized: below Android 12 the layout for the new size is chosen here.
    val data = ForYouData.parse(HomeWidgetPlugin.getData(context).getString(ForYouData.DATA_KEY, null))
    appWidgetManager.updateAppWidget(
        appWidgetId, views(context, appWidgetManager, appWidgetId, data, System.currentTimeMillis()))
  }

  override fun onDisabled(context: Context) {
    super.onDisabled(context)
    // The last one was removed: nothing left to read for or redraw.
    ForYouRefresh.cancel(context)
    HomeWidgetScheduler.cancel(context, javaClass.name)
  }

  /** The next listed event's end, when it drops off the rows. */
  private fun bookNextRedraw(context: Context, data: ForYouData, now: Long) {
    val next = data.items.mapNotNull { it.endsAt ?: it.startsAt }.filter { it > now }.minOrNull()
    if (next == null) {
      HomeWidgetScheduler.cancel(context, javaClass.name)
    } else {
      HomeWidgetScheduler.schedule(context, javaClass.name, listOf(next))
    }
  }

  private fun views(
      context: Context,
      manager: AppWidgetManager,
      id: Int,
      data: ForYouData,
      now: Long,
  ): RemoteViews {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
      // The launcher picks the largest that fits, and switches as it is resized.
      return RemoteViews(
          mapOf(
              SizeF(MEDIUM_MIN_DP, 80f) to render(context, data, now, large = false),
              SizeF(MEDIUM_MIN_DP, LARGE_MIN_HEIGHT_DP) to render(context, data, now, large = true),
          ))
    }
    val options = manager.getAppWidgetOptions(id)
    val height = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT)
    return render(context, data, now, large = height >= LARGE_MIN_HEIGHT_DP)
  }

  private fun render(context: Context, data: ForYouData, now: Long, large: Boolean): RemoteViews {
    val views =
        RemoteViews(
            context.packageName,
            if (large) R.layout.widget_for_you_large else R.layout.widget_for_you_medium)
    val seeAll = open(context, ForYouData.SEE_ALL_LINK)
    views.setOnClickPendingIntent(R.id.for_you_root, seeAll)
    val rows = if (large) ForYouData.LARGE_ROWS else ForYouData.MEDIUM_ROWS
    val items = data.upcomingAt(now, rows)
    if (items.isEmpty()) {
      views.setViewVisibility(R.id.for_you_events, View.GONE)
      views.setViewVisibility(R.id.for_you_message, View.VISIBLE)
      return views
    }
    views.setViewVisibility(R.id.for_you_message, View.GONE)
    views.setViewVisibility(R.id.for_you_events, View.VISIBLE)
    views.setTextViewText(R.id.for_you_header, data.header ?: context.getString(R.string.for_you_label))
    views.setOnClickPendingIntent(R.id.for_you_see_all, seeAll)
    for (row in 0 until rows) {
      val ids = ROW_IDS[row]
      val item = items.getOrNull(row)
      val shown = if (item == null) View.GONE else View.VISIBLE
      views.setViewVisibility(ids.row, shown)
      ids.divider?.let { views.setViewVisibility(it, shown) }
      if (item == null) continue
      views.setImageViewBitmap(
          ids.date,
          WidgetType.dateBlock(
              context,
              weekday = item.weekday,
              day = item.day,
              month = item.month,
              large = false,
              color = context.getColor(R.color.next_up_date_ink),
              mini = true,
          ))
      views.setContentDescription(ids.date, item.date)
      views.setTextViewText(ids.name, item.name)
      views.setTextViewText(ids.details, item.details)
      views.setOnClickPendingIntent(ids.row, open(context, item.link))
    }
    if (large) {
      views.setViewVisibility(R.id.for_you_more, if (items.size < rows) View.VISIBLE else View.GONE)
      views.setOnClickPendingIntent(R.id.for_you_more, seeAll)
    }
    return views
  }

  private fun open(context: Context, link: String) =
      HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse(link))

  /** One row's views. */
  private class RowIds(val row: Int, val divider: Int?, val date: Int, val name: Int, val details: Int)

  companion object {
    /** The width (dp) from which the widget lists events: about 4 cells. */
    private const val MEDIUM_MIN_DP = 220f

    /** The height (dp) from which the large layout is used: about 4 cells. */
    private const val LARGE_MIN_HEIGHT_DP = 240f

    private val ROW_IDS =
        listOf(
            RowIds(
                R.id.for_you_row_0, null, R.id.for_you_row_0_date, R.id.for_you_row_0_name,
                R.id.for_you_row_0_details),
            RowIds(
                R.id.for_you_row_1, R.id.for_you_divider_1, R.id.for_you_row_1_date,
                R.id.for_you_row_1_name, R.id.for_you_row_1_details),
            RowIds(
                R.id.for_you_row_2, R.id.for_you_divider_2, R.id.for_you_row_2_date,
                R.id.for_you_row_2_name, R.id.for_you_row_2_details),
            RowIds(
                R.id.for_you_row_3, R.id.for_you_divider_3, R.id.for_you_row_3_date,
                R.id.for_you_row_3_name, R.id.for_you_row_3_details),
        )

    /** Draw every "For you" widget again from what is kept (after a read). */
    fun redraw(context: Context) {
      val manager = AppWidgetManager.getInstance(context)
      val ids = manager.getAppWidgetIds(ComponentName(context, ForYouWidgetProvider::class.java))
      if (ids.isEmpty()) return
      context.sendBroadcast(
          Intent(context, ForYouWidgetProvider::class.java)
              .setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE)
              .putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids))
    }
  }
}
