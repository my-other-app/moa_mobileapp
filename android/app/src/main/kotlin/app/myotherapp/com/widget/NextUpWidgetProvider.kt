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
 * The app writes what to show (lib/features/home_widget); this only lays it out, in two sizes --
 * small (the date and the name) and medium (adds the place, the time and "Show ticket") -- chosen
 * by the widget's width. The line that depends on the clock ("Today · 9:30 am", "In 3 days") is
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
          )
      )
    }
    val width = manager.getAppWidgetOptions(id).getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
    return render(context, width >= MEDIUM_MIN_DP, data, now)
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
    views.setOnClickPendingIntent(
        R.id.next_up_root,
        HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse(link)),
    )
    return views
  }

  private fun fillEvent(
      context: Context,
      views: RemoteViews,
      item: NextUpItem,
      medium: Boolean,
      now: Long,
  ) {
    if (item.day == null) {
      // No date yet.
      views.setTextViewText(R.id.next_up_weekday, "")
      views.setTextViewText(R.id.next_up_day, "—")
      views.setTextViewText(R.id.next_up_month, "TBA")
    } else {
      views.setTextViewText(R.id.next_up_weekday, item.weekday ?: "")
      views.setTextViewText(R.id.next_up_day, item.day)
      views.setTextViewText(R.id.next_up_month, item.month ?: "")
    }
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

  companion object {
    /** Widths (dp) from which each size is used: a 2-cell widget is about 110 dp wide. */
    private const val SMALL_MIN_DP = 100f
    private const val MEDIUM_MIN_DP = 220f
  }
}
