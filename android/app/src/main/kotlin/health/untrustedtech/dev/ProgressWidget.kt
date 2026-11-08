package health.untrustedtech.dev

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.widget.RemoteViews
import androidx.core.graphics.ColorUtils
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.concurrent.TimeUnit
import es.antonborri.home_widget.HomeWidgetProvider

/** Workout totals, week streak and a heatmap of recent weeks. */
class ProgressWidget : HomeWidgetProvider() {
    companion object {
        private const val GREEN = 0xFF2EC7A5.toInt()
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val data = WidgetData(widgetData)
        WidgetRefresh.atMidnight(context, javaClass)
        if (LockedWidget.showIfHidden(context, appWidgetManager, appWidgetIds, data)) return
        val fresh = catchUp(
            widgetData.getString("progHeat", null) ?: "",
            widgetData.getString("date", null),
        )
        val theme = WidgetTheme(context, data, GREEN)
        val heat = drawHeat(context, fresh.heat, theme.track, theme.accent)
        val open = WidgetLink.open(context, "health://stats")
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.widget_progress).apply {
                setTextViewText(R.id.workouts, "%,d".format(data.value("progWorkouts")))
                setTextViewText(
                    R.id.month,
                    "%,d".format(if (fresh.newMonth) 0L else data.value("progMonth")),
                )
                setTextViewText(R.id.streak, "%,d".format(data.value("progStreak")))
                setImageViewBitmap(R.id.heat, heat)
                theme.apply(
                    this,
                    R.id.root,
                    labels = intArrayOf(R.id.workouts, R.id.month, R.id.streak),
                    secondaries = intArrayOf(R.id.workouts_label, R.id.month_label, R.id.streak_label),
                    accents = intArrayOf(R.id.title),
                    icons = intArrayOf(R.id.icon),
                )
                setOnClickPendingIntent(R.id.root, open)
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    private class Fresh(val heat: String, val newMonth: Boolean)

    /**
     * The app saves the grid as of the day it last ran. On later days (app
     * not opened) the days since then show as rest days, the grid moves on
     * by whole weeks, and "this month" starts again in a new month.
     */
    private fun catchUp(heat: String, saved: String?): Fresh {
        if (heat.isEmpty() || saved == null) return Fresh(heat, false)
        val format = SimpleDateFormat("yyyy-MM-dd", Locale.US)
        val then = try {
            format.parse(saved)
        } catch (e: java.text.ParseException) {
            null
        } ?: return Fresh(heat, false)
        val now = format.parse(format.format(Date())) ?: return Fresh(heat, false)
        // Rounded, so a 23- or 25-hour day (clock change) still counts as one.
        val days = ((now.time - then.time + TimeUnit.HOURS.toMillis(12)) / TimeUnit.DAYS.toMillis(1)).toInt()
        if (days <= 0) return Fresh(heat, false)
        val cal = Calendar.getInstance()
        cal.time = then
        val monthThen = cal.get(Calendar.YEAR) * 12 + cal.get(Calendar.MONTH)
        cal.time = now
        val newMonth = cal.get(Calendar.YEAR) * 12 + cal.get(Calendar.MONTH) != monthThen
        val chars = heat.toCharArray().toMutableList()
        var today = heat.indexOfLast { it != '-' } + days
        // Whole new weeks: drop the oldest, add empty future days.
        while (today >= chars.size) {
            repeat(7) { chars.removeAt(0); chars.add('-') }
            today -= 7
        }
        for (i in 0..today) if (chars[i] == '-') chars[i] = '0'
        return Fresh(String(chars.toCharArray()), newMonth)
    }

    /**
     * One column per week, Monday at the top: "0"–"4" for time trained,
     * "-" for days still to come. The last filled day (today) is outlined.
     */
    private fun drawHeat(context: Context, heat: String, empty: Int, colour: Int): Bitmap {
        val weeks = maxOf(1, (heat.length + 6) / 7)
        val density = context.resources.displayMetrics.density
        val cell = 14f * density
        val gap = 3f * density
        val width = (weeks * (cell + gap) - gap).toInt().coerceAtLeast(1)
        val height = (7 * (cell + gap) - gap).toInt()
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        val radius = cell * 0.28f
        val today = heat.indexOfLast { it != '-' }
        heat.forEachIndexed { i, ch ->
            val x = (i / 7) * (cell + gap)
            val y = (i % 7) * (cell + gap)
            val rect = RectF(x, y, x + cell, y + cell)
            paint.style = Paint.Style.FILL
            paint.color = when (ch) {
                '-' -> ColorUtils.setAlphaComponent(empty, Color.alpha(empty) / 2)
                '0' -> empty
                else -> {
                    val level = (ch - '1').coerceIn(0, 3)
                    ColorUtils.blendARGB(
                        ColorUtils.setAlphaComponent(colour, 77),
                        colour,
                        level / 3f,
                    )
                }
            }
            canvas.drawRoundRect(rect, radius, radius, paint)
            if (i == today) {
                paint.style = Paint.Style.STROKE
                paint.strokeWidth = 2f * density
                paint.color = colour
                rect.inset(density, density)
                canvas.drawRoundRect(rect, radius, radius, paint)
            }
        }
        return bitmap
    }
}
