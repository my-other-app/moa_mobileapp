package app.myotherapp.com.widget

import android.content.Context
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import java.io.File

/**
 * The small round photos of the people on "Recently met", kept by the app only when the person
 * turned on "Show people's photos in widgets" (lib/features/home_widget/data/widget_photos.dart,
 * docs/HOME_WIDGETS.md).
 *
 * Each is a PNG in the app's files, `home_widget/<key>.png` (home_widget's own folder), with its path
 * in home_widget's SharedPreferences under its key; the widget's JSON names the key of each person's
 * photo. The app makes them round, 96 px, so they are shown as they are. A photo that can't be read
 * -- deleted as the person turned photos off, say -- is drawn as initials.
 */
object WidgetPhotos {
  /** The folder home_widget keeps its files in, in the app's files. */
  const val FOLDER = "home_widget"

  /** The longest side a photo is decoded at: the app makes them 96 px. */
  const val MAX_PIXELS = 192

  /** The photos of [people], by key: only those that can be read. */
  fun load(context: Context, widgetData: SharedPreferences, people: List<MetPerson>): Map<String, Bitmap> {
    val folder = File(context.filesDir, FOLDER)
    val photos = mutableMapOf<String, Bitmap>()
    for (person in people) {
      val key = person.photo ?: continue
      if (photos.containsKey(key)) continue
      val path = widgetData.getString(key, null) ?: continue
      val file = allowedFile(path, folder) ?: continue
      decode(file)?.let { photos[key] = it }
    }
    return photos
  }

  /** [path] when it is a PNG straight inside [folder]; null for anywhere else. */
  fun allowedFile(path: String, folder: File): File? =
      try {
        val file = File(path).canonicalFile
        if (file.extension.equals("png", ignoreCase = true) &&
            file.parentFile == folder.canonicalFile && file.isFile)
            file
        else null
      } catch (e: Exception) {
        null
      }

  /** How much to scale a [width] x [height] picture down by, as a power of two, to fit [MAX_PIXELS]. */
  fun sampleSize(width: Int, height: Int): Int {
    var sample = 1
    while (maxOf(width, height) / sample > MAX_PIXELS) sample *= 2
    return sample
  }

  private fun decode(file: File): Bitmap? =
      try {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.path, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) null
        else
            BitmapFactory.decodeFile(
                file.path,
                BitmapFactory.Options().apply {
                  inSampleSize = sampleSize(bounds.outWidth, bounds.outHeight)
                })
      } catch (e: Exception) {
        null
      }
}
