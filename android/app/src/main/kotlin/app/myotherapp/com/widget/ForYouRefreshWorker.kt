package app.myotherapp.com.widget

import android.content.Context
import android.util.Log
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequest
import androidx.work.PeriodicWorkRequest
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import es.antonborri.home_widget.HomeWidgetPlugin
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.TimeUnit

/**
 * Reads the public front page (`GET {api}/discover/home`) for the "For you" widget while the app is
 * closed, picks what it lists ([ForYouPicker]) and keeps it, then redraws it (docs/HOME_WIDGETS.md).
 * No token: the page is public. It asks with the last answer's ETag, so an unchanged page is a 304
 * of a few hundred bytes.
 *
 * WorkManager (already in the app through home_widget) runs it every three hours while a widget is
 * placed, only on a network, batched with the phone's other background work.
 */
class ForYouRefreshWorker(context: Context, params: WorkerParameters) : Worker(context, params) {

  override fun doWork(): Result {
    val prefs = HomeWidgetPlugin.getData(applicationContext)
    val data = ForYouData.parse(prefs.getString(ForYouData.DATA_KEY, null))
    val url = data.ask.homeUrl() ?: return Result.success()
    val now = System.currentTimeMillis()
    val fresh =
        try {
          read(url, data, now)
        } catch (e: Exception) {
          Log.w(TAG, "could not read the front page: ${e.javaClass.simpleName}")
          null
        } ?: return if (runAttemptCount < 2) Result.retry() else Result.success()
    // The app wrote meanwhile for someone else (a sign-out, another city): theirs stands.
    val current = ForYouData.parse(prefs.getString(ForYouData.DATA_KEY, null))
    if (current.ask != data.ask) return Result.success()
    prefs.edit().putString(ForYouData.DATA_KEY, fresh.toJson()).apply()
    ForYouWidgetProvider.redraw(applicationContext)
    return Result.success()
  }

  /** [data] after reading the page at [url]; null when it can't be read. */
  private fun read(url: String, data: ForYouData, now: Long): ForYouData? {
    val connection = URL(url).openConnection() as HttpURLConnection
    try {
      connection.connectTimeout = TIMEOUT_MS
      connection.readTimeout = TIMEOUT_MS
      connection.useCaches = false
      connection.setRequestProperty("Accept", "application/json")
      if (data.etag != null && data.items.isNotEmpty()) {
        connection.setRequestProperty("If-None-Match", data.etag)
      }
      return when (connection.responseCode) {
        HttpURLConnection.HTTP_NOT_MODIFIED -> data.copy(fetchedAt = now)
        HttpURLConnection.HTTP_OK -> {
          val body = connection.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
          ForYouPicker.picked(body, data, now, connection.getHeaderField("ETag"))
        }
        else -> null
      }
    } finally {
      connection.disconnect()
    }
  }

  companion object {
    private const val TAG = "ForYouRefresh"
    private const val TIMEOUT_MS = 15_000
  }
}

/** When [ForYouRefreshWorker] runs. */
object ForYouRefresh {
  private const val EVERY = "for_you_refresh"
  private const val NOW = "for_you_refresh_now"

  private val online = Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build()

  /** Every three hours while a widget is placed (kept if already booked). */
  fun schedule(context: Context) {
    try {
      WorkManager.getInstance(context)
          .enqueueUniquePeriodicWork(
              EVERY,
              ExistingPeriodicWorkPolicy.KEEP,
              PeriodicWorkRequest.Builder(ForYouRefreshWorker::class.java, 3, TimeUnit.HOURS)
                  .setConstraints(online)
                  .build())
    } catch (e: Exception) {
      Log.w("ForYouRefresh", "could not book the refresh", e)
    }
  }

  /**
   * Once, as soon as there is a network. A read already waiting or running is replaced: what to
   * ask may have changed (a sign-out, another city).
   */
  fun now(context: Context) {
    try {
      WorkManager.getInstance(context)
          .enqueueUniqueWork(
              NOW,
              ExistingWorkPolicy.REPLACE,
              OneTimeWorkRequest.Builder(ForYouRefreshWorker::class.java)
                  .setConstraints(online)
                  .build())
    } catch (e: Exception) {
      Log.w("ForYouRefresh", "could not ask for a read", e)
    }
  }

  /** No widget left: no more reading. */
  fun cancel(context: Context) {
    try {
      val work = WorkManager.getInstance(context)
      work.cancelUniqueWork(EVERY)
      work.cancelUniqueWork(NOW)
    } catch (e: Exception) {
      Log.w("ForYouRefresh", "could not cancel", e)
    }
  }
}
