package health.untrustedtech.dev

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Matrix
import android.graphics.RectF
import android.graphics.SweepGradient
import androidx.core.graphics.ColorUtils

/** Draws Apple-style concentric activity rings into a bitmap. */
object RingRenderer {
    val MOVE = Color.rgb(255, 77, 125)
    val EXERCISE = Color.rgb(46, 230, 197)
    val STEPS = Color.rgb(139, 156, 255)

    fun draw(sizePx: Int, progress: List<Float>, colors: List<Int>): Bitmap {
        val bitmap = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val stroke = sizePx * 0.11f
        val gap = stroke * 0.2f
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = stroke
            strokeCap = Paint.Cap.ROUND
        }
        progress.forEachIndexed { i, p ->
            val inset = stroke / 2 + i * (stroke + gap)
            val rect = RectF(inset, inset, sizePx - inset, sizePx - inset)
            if (rect.width() <= 0) return@forEachIndexed
            val color = colors[i]
            paint.shader = null
            paint.color = color
            paint.alpha = 55
            canvas.drawArc(rect, 0f, 360f, false, paint)
            paint.alpha = 255
            val sweep = 360f * p.coerceIn(0f, 2f)
            if (sweep <= 0f) return@forEachIndexed
            // Gradient arc like the Fitness app: darker start, brighter head.
            val dark = ColorUtils.blendARGB(color, Color.BLACK, 0.22f)
            val light = ColorUtils.blendARGB(color, Color.WHITE, 0.08f)
            val cx = rect.centerX()
            val cy = rect.centerY()
            val end = (sweep.coerceAtMost(359.9f)) / 360f
            paint.shader = SweepGradient(
                cx, cy, intArrayOf(dark, light, light), floatArrayOf(0f, end, 1f),
            ).apply {
                setLocalMatrix(Matrix().apply { postRotate(-90f, cx, cy) })
            }
            canvas.drawArc(rect, -90f, sweep.coerceAtMost(359.9f), false, paint)
        }
        return bitmap
    }
}
