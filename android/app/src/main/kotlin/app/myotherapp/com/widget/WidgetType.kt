package app.myotherapp.com.widget

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.Typeface
import android.util.TypedValue
import kotlin.math.ceil
import kotlin.math.max

/**
 * The app's display face in the home-screen widgets (docs/HOME_WIDGETS.md, "Fonts").
 *
 * A widget's text can't be set in a custom font: the launcher inflates the layout in a restricted
 * context, and there TextView ignores a font resource (`android:fontFamily="@font/…"` falls back to
 * the system font) -- on every Android version that has font resources, 8.0 onwards. So the
 * widgets' text stays in the system's sans-serif, and the date block -- three short words in Bebas
 * Neue, as on the app's tickets -- is drawn here, in the app's own process, into a bitmap the widget
 * shows.
 *
 * The face is the app's own file, read from its Flutter assets; should it be missing, a condensed
 * bold system face stands in.
 */
object WidgetType {
  /** Bebas Neue as the APK carries it: Flutter's assets, pubspec.yaml's `assets/fonts/`. */
  const val DISPLAY_ASSET = "flutter_assets/assets/fonts/BebasNeue-Regular.ttf"

  @Volatile private var display: Typeface? = null

  /** Bebas Neue, loaded once per process. */
  fun display(context: Context): Typeface =
      display
          ?: synchronized(this) {
            display ?: load(context).also { display = it }
          }

  private fun load(context: Context): Typeface =
      try {
        Typeface.createFromAsset(context.applicationContext.assets, DISPLAY_ASSET)
      } catch (e: RuntimeException) {
        Typeface.create("sans-serif-condensed", Typeface.BOLD)
      }

  /**
   * The date block's words -- [weekday], [day], [month], one under the other, centred -- in
   * [color] on a clear ground; [large] for the medium widget. Sizes are in sp, so the block follows
   * the phone's font size as the widget's text does.
   */
  fun dateBlock(
      context: Context,
      weekday: String,
      day: String,
      month: String,
      large: Boolean,
      color: Int,
  ): Bitmap {
    val metrics = context.resources.displayMetrics
    fun sp(value: Float) = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, value, metrics)
    fun dp(value: Float) = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, value, metrics)

    val face = display(context)
    val words = listOf(weekday, day, month)
    val sizes =
        if (large) listOf(sp(14f), sp(38f), sp(14f)) else listOf(sp(12f), sp(30f), sp(12f))
    val paints =
        sizes.map { size ->
          Paint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = face
            textSize = size
            this.color = color
            textAlign = Paint.Align.CENTER
          }
        }
    // Bebas Neue has only capitals and figures: each line is as tall as a capital.
    val heights =
        paints.map { paint -> Rect().also { paint.getTextBounds("H0", 0, 2, it) }.height().toFloat() }
    val gap = dp(if (large) 5f else 4f)
    val widest = words.indices.maxOf { paints[it].measureText(words[it]) }
    val width = max(widest, dp(if (large) 40f else 32f))
    val height = heights.sum() + gap * 2

    val bitmap =
        Bitmap.createBitmap(ceil(width).toInt(), ceil(height).toInt(), Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap)
    var baseline = 0f
    for (i in words.indices) {
      baseline += heights[i]
      canvas.drawText(words[i], bitmap.width / 2f, baseline, paints[i])
      baseline += gap
    }
    return bitmap
  }
}
