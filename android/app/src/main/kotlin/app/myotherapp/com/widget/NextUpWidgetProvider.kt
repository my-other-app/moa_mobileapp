package app.myotherapp.com.widget

import android.appwidget.AppWidgetManager
import android.content.Context
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
 * "Next up", the home-screen widget (docs/HOME_WIDGETS.md): the next event the person holds a
 * ticket for, or a registration under review; "Find events" with nothing coming up; "Sign in to
 * see your next event" signed out.
 *
 * The app writes what to show (lib/features/home_widget); this only lays it out, in three sizes --
 * small (the date and the name), medium (adds the place, the time and "Show ticket") and large
 * (from about 4x4: the next three, each row opening its own ticket) -- chosen by the widget's size. The line that depends on the clock ("Today · 9:30 am", "In 3 days") is
 * worked out here as it draws, on India's clock, and a redraw is booked for the next moment it
 * changes (midnight in India, or an event starting or ending), through home_widget's scheduler.
 *
 * A tap opens the website's address for the event's ticket (`/events/{id}/ticket`), which the
 * app's router reads as its own page (Flutter deep linking): the ticket's code is never here.
 */
class NextUpWidgetProvider : HomeWidgetProvider() {

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    val data = NextUpData.parse(widgetData.getString(NextUpData.DATA_KEY, null))
    val now = System.currentTimeMillis()
    for (id in appWidgetIds) {
      appWidgetManager.updateAppWidget(id, views(context, appWidgetManager, id, data, now))
    }
    bookNextRedraw(context, data, now)
  }

  override fun onAppWidgetOptionsChanged(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetId: Int,
      newOptions: Bundle,
  ) {
    super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
    // Resized: below Android 12 the layout for the new size is chosen here.
    val data = read(context)
    appWidgetManager.updateAppWidget(
        appWidgetId,
        views(context, appWidgetManager, appWidgetId, data, System.currentTimeMillis()),
    )
  }

  override fun onDisabled(context: Context) {
    super.onDisabled(context)
    // The last one was removed: nothing left to redraw.
    HomeWidgetScheduler.cancel(context, javaClass.name)
  }

  private fun read(context: Context): NextUpData =
      NextUpData.parse(HomeWidgetPlugin.getData(context).getString(NextUpData.DATA_KEY, null))

  private fun bookNextRedraw(context: Context, data: NextUpData, now: Long) {
    val next = IndiaClock.nextChange(data, now)
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
      data: NextUpData,
      now: Long,
  ): RemoteViews {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
      // The launcher picks the largest that fits, and switches as it is resized.
      return RemoteViews(
          mapOf(
              SizeF(SMALL_MIN_DP, 80f) to render(context, false, data, now),
              SizeF(MEDIUM_MIN_DP, 80f) to render(context, true, data, now),
              SizeF(MEDIUM_MIN_DP, LARGE_MIN_HEIGHT_DP) to renderLarge(context, data, now),
          )
      )
    }
    // Below Android 12: the width picks small or medium, and the height (in portrait, the widget's
    // tallest) large.
    val options = manager.getAppWidgetOptions(id)
    val width = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
    val height = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT)
    if (width >= MEDIUM_MIN_DP && height >= LARGE_MIN_HEIGHT_DP) return renderLarge(context, data, now)
    return render(context, width >= MEDIUM_MIN_DP, data, now)
  }

  /**
   * Large: up to three events not over yet, soonest first. Each row opens its own ticket (or the
   * event, for a registration under review); the first has "Show ticket". Fewer than three: a soft
   * panel with "Find more events" in the others' place. Nothing coming up, or signed out: the
   * message, as medium.
   */
  private fun renderLarge(context: Context, data: NextUpData, now: Long): RemoteViews {
    val views = RemoteViews(context.packageName, R.layout.widget_next_up_large)
    val items = data.upcomingAt(now, LARGE_ROWS)
    if (items.isEmpty()) {
      views.setViewVisibility(R.id.next_up_event, View.GONE)
      views.setViewVisibility(R.id.next_up_message, View.VISIBLE)
      val signedOut = data.state == NextUpData.SIGNED_OUT
      views.setTextViewText(
          R.id.next_up_message_title,
          context.getString(if (signedOut) R.string.next_up_signed_out else R.string.next_up_nothing))
      views.setTextViewText(
          R.id.next_up_message_action,
          context.getString(if (signedOut) R.string.next_up_sign_in else R.string.next_up_find_events))
      views.setOnClickPendingIntent(
          R.id.next_up_root,
          open(context, if (signedOut) data.link else NextUpData.FIND_EVENTS_LINK))
      return views
    }
    views.setViewVisibility(R.id.next_up_message, View.GONE)
    views.setViewVisibility(R.id.next_up_event, View.VISIBLE)
    views.setOnClickPendingIntent(R.id.next_up_root, open(context, items.first().link))
    for (row in 0 until LARGE_ROWS) {
      val ids = LARGE_ROW_IDS[row]
      val item = items.getOrNull(row)
      views.setViewVisibility(ids.row, if (item == null) View.GONE else View.VISIBLE)
      if (item == null) continue
      setDateBlock(context, views, ids.date, item, large = false)
      views.setTextViewText(ids.whenLine, largeWhen(context, item, now, first = row == 0))
      views.setTextViewText(ids.name, item.name)
      val place = item.place ?: item.club
      views.setViewVisibility(ids.place, if (place == null) View.GONE else View.VISIBLE)
      views.setTextViewText(ids.place, place ?: "")
      views.setOnClickPendingIntent(ids.row, open(context, item.link))
    }
    // Fewer than three: a soft panel offers more, in the place of those missing.
    val findMore = open(context, NextUpData.FIND_EVENTS_LINK)
    views.setViewVisibility(R.id.next_up_rest, if (items.size > 1) View.VISIBLE else View.GONE)
    views.setViewVisibility(R.id.next_up_more, if (items.size == 1) View.VISIBLE else View.GONE)
    views.setViewVisibility(R.id.next_up_more_small, if (items.size == 2) View.VISIBLE else View.GONE)
    views.setOnClickPendingIntent(R.id.next_up_more, findMore)
    views.setOnClickPendingIntent(R.id.next_up_more_small, findMore)
    val first = items.first()
    if (first.underReview) {
      views.setViewVisibility(R.id.next_up_show_ticket, View.GONE)
      views.setViewVisibility(R.id.next_up_review, View.VISIBLE)
      views.setTextViewText(
          R.id.next_up_review, first.badge ?: context.getString(R.string.next_up_under_review))
    } else {
      views.setViewVisibility(R.id.next_up_review, View.GONE)
      views.setViewVisibility(R.id.next_up_show_ticket, View.VISIBLE)
    }
    return views
  }

  /** A large row's line: when; for a registration under review (after the first), its badge too. */
  private fun largeWhen(context: Context, item: NextUpItem, now: Long, first: Boolean): String {
    val line = IndiaClock.whenLine(item, now)
    if (!item.underReview || first) return line
    return "$line · ${item.badge ?: context.getString(R.string.next_up_under_review)}"
  }

  private fun open(context: Context, link: String) =
      HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse(link))

  /** The date block, in Bebas Neue (WidgetType): "SAT / 28 / NOV", or "— / TBA" with no date yet. */
  private fun setDateBlock(
      context: Context,
      views: RemoteViews,
      viewId: Int,
      item: NextUpItem,
      large: Boolean,
  ) {
    val dated = item.day != null
    views.setImageViewBitmap(
        viewId,
        WidgetType.dateBlock(
            context,
            weekday = if (dated) item.weekday ?: "" else "",
            day = item.day ?: "—",
            month = if (dated) item.month ?: "" else "TBA",
            large = large,
            color = context.getColor(R.color.next_up_date_ink),
        ),
    )
    views.setContentDescription(
        viewId,
        if (dated) item.date ?: listOfNotNull(item.weekday, item.day, item.month).joinToString(" ")
        else context.getString(R.string.next_up_date_unknown),
    )
  }

  private fun render(context: Context, medium: Boolean, data: NextUpData, now: Long): RemoteViews {
    val views =
        RemoteViews(
            context.packageName,
            if (medium) R.layout.widget_next_up_medium else R.layout.widget_next_up_small,
        )
    val item = if (data.state == NextUpData.UPCOMING) data.nextAt(now) else null
    val link: String
    if (item == null) {
      views.setViewVisibility(R.id.next_up_event, View.GONE)
      views.setViewVisibility(R.id.next_up_message, View.VISIBLE)
      if (data.state == NextUpData.SIGNED_OUT) {
        views.setTextViewText(R.id.next_up_message_title, context.getString(R.string.next_up_signed_out))
        views.setTextViewText(R.id.next_up_message_action, context.getString(R.string.next_up_sign_in))
        link = data.link
      } else {
        views.setTextViewText(R.id.next_up_message_title, context.getString(R.string.next_up_nothing))
        views.setTextViewText(R.id.next_up_message_action, context.getString(R.string.next_up_find_events))
        link = NextUpData.FIND_EVENTS_LINK
      }
    } else {
      views.setViewVisibility(R.id.next_up_message, View.GONE)
      views.setViewVisibility(R.id.next_up_event, View.VISIBLE)
      fillEvent(context, views, item, medium, now)
      link = item.link
    }
    views.setOnClickPendingIntent(R.id.next_up_root, open(context, link))
    return views
  }

  private fun fillEvent(
      context: Context,
      views: RemoteViews,
      item: NextUpItem,
      medium: Boolean,
      now: Long,
  ) {
    setDateBlock(context, views, R.id.next_up_date, item, large = medium)
    views.setTextViewText(R.id.next_up_name, item.name)
    views.setTextViewText(R.id.next_up_when, IndiaClock.whenLine(item, now))
    if (!medium) {
      // Small: "Next up" over the name, or what stands in for the ticket.
      views.setTextViewText(
          R.id.next_up_label,
          if (item.underReview) item.badge ?: context.getString(R.string.next_up_under_review)
          else context.getString(R.string.next_up_label),
      )
      return
    }

    // Medium: the time and the place (or the club), and the ticket's pill.
    val details = listOfNotNull(item.time, item.place ?: item.club).joinToString(" · ")
    views.setViewVisibility(R.id.next_up_place, if (details.isEmpty()) View.GONE else View.VISIBLE)
    views.setTextViewText(R.id.next_up_place, details)
    if (item.underReview) {
      views.setViewVisibility(R.id.next_up_show_ticket, View.GONE)
      views.setViewVisibility(R.id.next_up_review, View.VISIBLE)
      views.setTextViewText(
          R.id.next_up_review,
          item.badge ?: context.getString(R.string.next_up_under_review),
      )
    } else {
      views.setViewVisibility(R.id.next_up_review, View.GONE)
      views.setViewVisibility(R.id.next_up_show_ticket, View.VISIBLE)
    }
  }

  /** One large row's views. */
  private class RowIds(val row: Int, val date: Int, val whenLine: Int, val name: Int, val place: Int)

  companion object {
    /** Widths (dp) from which each size is used: a 2-cell widget is about 110 dp wide. */
    private const val SMALL_MIN_DP = 100f
    private const val MEDIUM_MIN_DP = 220f

    /** The height (dp) from which the large layout is used: about 4 cells. */
    private const val LARGE_MIN_HEIGHT_DP = 240f

    /** How many events the large widget lists. */
    const val LARGE_ROWS = 3

    private val LARGE_ROW_IDS =
        listOf(
            RowIds(
                R.id.next_up_row_0, R.id.next_up_row_0_date, R.id.next_up_row_0_when,
                R.id.next_up_row_0_name, R.id.next_up_row_0_place),
            RowIds(
                R.id.next_up_row_1, R.id.next_up_row_1_date, R.id.next_up_row_1_when,
                R.id.next_up_row_1_name, R.id.next_up_row_1_place),
            RowIds(
                R.id.next_up_row_2, R.id.next_up_row_2_date, R.id.next_up_row_2_when,
                R.id.next_up_row_2_name, R.id.next_up_row_2_place),
        )
  }
}
