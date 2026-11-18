package app.myotherapp.com.eventday

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.drawable.Icon
import android.os.Build
import android.os.Bundle
import android.util.Log
import app.myotherapp.com.R
import app.myotherapp.com.tiles.PageTiles
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone

/**
 * The event-day card on Android (docs/HOME_WIDGETS.md, "Event-day card"): an ongoing notification
 * on the day of an event the person holds a ticket for -- the event's name, a countdown to its
 * start that the system runs by itself (a Chronometer counting down), the venue, and "Show
 * ticket". From the start it says it is happening now; after the end it goes. One at a time.
 *
 * Shown on its own channel, "Event day" (quiet: no sound, no vibration), and only where the app may
 * notify (Android 13's permission, the app's notifications and the channel all on). Drawn on the
 * lock screen in full: it holds only the event's name, time and venue -- never the ticket's code.
 * Its taps open the ticket's page in the app through the link path the widgets use.
 *
 * Started, updated and ended from Dart (lib/features/home_widget/data/event_day_platform.dart, the
 * `finnet/event_day` channel); an alarm at the start redraws it as started, one at the end takes it
 * away (and Android 8's timeout too), so it moves on while the app is closed.
 */
object EventDayNotifications {
  const val CHANNEL = "finnet/event_day"
  const val CHANNEL_ID = "event_day"
  private const val TAG = "EventDay"
  private const val NOTIFICATION_ID = 7301
  private const val EXTRA_EVENT = "event_day_event_id"
  const val ACTION_STARTED = "app.myotherapp.com.eventday.STARTED"
  const val ACTION_ENDED = "app.myotherapp.com.eventday.ENDED"

  fun register(messenger: BinaryMessenger, context: Context) {
    val app = context.applicationContext
    MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
      try {
        when (call.method) {
          "supported" -> result.success(true)
          "start" -> {
            val card = EventDayCard.from(call.arguments)
            result.success(card != null && show(app, card))
          }
          "update" -> {
            val card = EventDayCard.from(call.arguments)
            result.success(card != null && current(app) == card.eventId && show(app, card))
          }
          "end" -> {
            end(app)
            result.success(null)
          }
          "current" -> result.success(current(app)?.toInt())
          else -> result.notImplemented()
        }
      } catch (e: Exception) {
        Log.w(TAG, "event-day card: ${call.method}", e)
        result.success(if (call.method == "end" || call.method == "current") null else false)
      }
    }
  }

  /** Whether the app may show it: its notifications on (and permitted), the channel not off. */
  fun canShow(context: Context): Boolean {
    val manager = context.getSystemService(NotificationManager::class.java) ?: return false
    if (!manager.areNotificationsEnabled()) return false
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      val channel = manager.getNotificationChannel(CHANNEL_ID)
      if (channel != null && channel.importance == NotificationManager.IMPORTANCE_NONE) return false
    }
    return true
  }

  /** Put [card] up (replacing any other), as it stands now. False when it can't be shown. */
  fun show(context: Context, card: EventDayCard, now: Long = System.currentTimeMillis()): Boolean {
    if (card.phaseAt(now) == EventDayCard.Phase.OVER) {
      end(context)
      return false
    }
    if (!canShow(context)) return false
    val manager = context.getSystemService(NotificationManager::class.java) ?: return false
    ensureChannel(context, manager)
    manager.notify(NOTIFICATION_ID, build(context, card, now))
    book(context, card, now)
    return true
  }

  /** Every card down, and its alarms cancelled. */
  fun end(context: Context) {
    context.getSystemService(NotificationManager::class.java)?.cancel(NOTIFICATION_ID)
    val alarms = context.getSystemService(AlarmManager::class.java) ?: return
    alarms.cancel(alarm(context, ACTION_STARTED, null))
    alarms.cancel(alarm(context, ACTION_ENDED, null))
  }

  /** The event whose card is up, if any. */
  fun current(context: Context): Long? {
    val manager = context.getSystemService(NotificationManager::class.java) ?: return null
    return manager.activeNotifications
        .firstOrNull { it.id == NOTIFICATION_ID }
        ?.notification
        ?.extras
        ?.getLong(EXTRA_EVENT, 0L)
        ?.takeIf { it > 0 }
  }

  private fun ensureChannel(context: Context, manager: NotificationManager) {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
    if (manager.getNotificationChannel(CHANNEL_ID) != null) return
    val channel =
        NotificationChannel(
            CHANNEL_ID,
            context.getString(R.string.event_day_channel),
            NotificationManager.IMPORTANCE_DEFAULT)
    channel.description = context.getString(R.string.event_day_channel_description)
    channel.setSound(null, null)
    channel.enableVibration(false)
    channel.setShowBadge(false)
    channel.lockscreenVisibility = Notification.VISIBILITY_PUBLIC
    manager.createNotificationChannel(channel)
  }

  private fun build(context: Context, card: EventDayCard, now: Long): Notification {
    val builder =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
          Notification.Builder(context, CHANNEL_ID)
        } else {
          @Suppress("DEPRECATION") Notification.Builder(context)
        }
    val soon = card.phaseAt(now) == EventDayCard.Phase.SOON
    val open = page(context, card.link, 1)
    builder
        .setSmallIcon(R.drawable.ic_stat_notification)
        .setColor(context.getColor(R.color.notification_accent))
        .setContentTitle(card.name)
        .setContentText(card.lineAt(now, indiaTime(card.endsAt)))
        .setSubText(context.getString(R.string.event_day_label))
        .setCategory(Notification.CATEGORY_EVENT)
        .setVisibility(Notification.VISIBILITY_PUBLIC)
        .setOngoing(true)
        .setOnlyAlertOnce(true)
        .setAutoCancel(false)
        .setContentIntent(open)
        .addAction(
            Notification.Action.Builder(
                    Icon.createWithResource(context, R.drawable.ic_stat_notification),
                    context.getString(R.string.event_day_show_ticket),
                    page(context, card.link, 2))
                .build())
        .setExtras(Bundle().apply { putLong(EXTRA_EVENT, card.eventId) })
        // Before the start: the time left, counted down by the system.
        .setWhen(card.startsAt)
        .setShowWhen(soon)
        .setUsesChronometer(soon)
    if (soon) builder.setChronometerCountDown(true)
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      // Gone at the end even if the alarm is late.
      builder.setTimeoutAfter(card.endsAt - now)
    }
    return builder.build()
  }

  /** The ticket's page in the app: the link path the widgets and tiles use. */
  private fun page(context: Context, link: String, code: Int): PendingIntent =
      PendingIntent.getActivity(
          context,
          NOTIFICATION_ID + code,
          PageTiles.intentFor(context, link),
          PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)

  /** An alarm at the start (to say it started) and at the end (to take it down). */
  private fun book(context: Context, card: EventDayCard, now: Long) {
    val alarms = context.getSystemService(AlarmManager::class.java) ?: return
    if (card.startsAt > now) {
      alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, card.startsAt, alarm(context, ACTION_STARTED, card))
    } else {
      alarms.cancel(alarm(context, ACTION_STARTED, null))
    }
    alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, card.endsAt, alarm(context, ACTION_ENDED, card))
  }

  private fun alarm(context: Context, action: String, card: EventDayCard?): PendingIntent {
    val intent = Intent(context, EventDayReceiver::class.java).setAction(action)
    if (card != null) intent.putExtras(bundle(card))
    return PendingIntent.getBroadcast(
        context,
        if (action == ACTION_STARTED) NOTIFICATION_ID + 3 else NOTIFICATION_ID + 4,
        intent,
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
  }

  private fun bundle(card: EventDayCard): Bundle =
      Bundle().apply {
        putLong("event_id", card.eventId)
        putString("name", card.name)
        putString("place", card.place)
        putLong("starts_at", card.startsAt)
        putLong("ends_at", card.endsAt)
        putString("time", card.time)
        putString("link", card.link)
      }

  fun cardOf(extras: Bundle?): EventDayCard? {
    if (extras == null) return null
    return EventDayCard.from(
        mapOf(
            "event_id" to extras.getLong("event_id"),
            "name" to extras.getString("name"),
            "place" to extras.getString("place"),
            "starts_at" to extras.getLong("starts_at"),
            "ends_at" to extras.getLong("ends_at"),
            "time" to extras.getString("time"),
            "link" to extras.getString("link"),
        ))
  }

  /** "5:30 pm", in India. */
  fun indiaTime(millis: Long): String {
    val format = SimpleDateFormat("h:mm a", Locale.ENGLISH)
    format.timeZone = TimeZone.getTimeZone("GMT+05:30")
    return format.format(millis).lowercase(Locale.ENGLISH)
  }
}

/**
 * The card's alarms: at the start it is drawn again as started; at the end it goes. Only when the
 * card up is still that event's (the person may have put it away, or another came up).
 */
class EventDayReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) {
    val card = EventDayNotifications.cardOf(intent.extras) ?: return
    if (EventDayNotifications.current(context) != card.eventId) return
    when (intent.action) {
      EventDayNotifications.ACTION_STARTED -> EventDayNotifications.show(context, card)
      EventDayNotifications.ACTION_ENDED -> EventDayNotifications.end(context)
    }
  }
}
