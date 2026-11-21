package app.myotherapp.com.widget

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import com.google.zxing.WriterException
import com.google.zxing.qrcode.decoder.ErrorCorrectionLevel
import com.google.zxing.qrcode.encoder.Encoder

/**
 * The person's QR code for the "Networking" widget, made in the widget from the link the app wrote
 * (NetworkingData.qrPayload): nothing but the link is stored, and the code always matches it.
 *
 * Encoded with ZXing's core encoder (error correction M) and drawn here: dark modules on a white
 * tile with a quiet zone of four modules -- also in the dark theme -- so any camera reads it.
 */
object QrBitmap {
  /** The quiet zone, in modules (the QR standard's minimum). */
  const val QUIET_ZONE = 4

  /** The modules of [text]'s code, row by row (true is dark), without a margin; null if it can't be made. */
  fun modules(text: String): Array<BooleanArray>? {
    if (text.isEmpty()) return null
    return try {
      val matrix = Encoder.encode(text, ErrorCorrectionLevel.M).matrix
      Array(matrix.height) { y -> BooleanArray(matrix.width) { x -> matrix.get(x, y).toInt() == 1 } }
    } catch (e: WriterException) {
      null
    }
  }

  /**
   * [modules] on a white tile with rounded corners, [modulePx] pixels to a module, the quiet zone
   * around. About 370 px square for a profile link: sharp at a widget's size.
   */
  fun tile(modules: Array<BooleanArray>, modulePx: Int = 10): Bitmap {
    val side = (modules.size + QUIET_ZONE * 2) * modulePx
    val bitmap = Bitmap.createBitmap(side, side, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap)
    val white = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE }
    val radius = modulePx * 1.5f
    canvas.drawRoundRect(RectF(0f, 0f, side.toFloat(), side.toFloat()), radius, radius, white)
    val dark = Paint().apply { color = Color.BLACK }
    for (y in modules.indices) {
      val row = modules[y]
      for (x in row.indices) {
        if (!row[x]) continue
        val left = ((x + QUIET_ZONE) * modulePx).toFloat()
        val top = ((y + QUIET_ZONE) * modulePx).toFloat()
        canvas.drawRect(left, top, left + modulePx, top + modulePx, dark)
      }
    }
    return bitmap
  }

  /** [text]'s code on its tile; null if it can't be made. */
  fun tile(text: String): Bitmap? = modules(text)?.let { tile(it) }
}
