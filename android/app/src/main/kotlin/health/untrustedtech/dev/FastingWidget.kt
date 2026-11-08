package health.untrustedtech.dev

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.DateFormat
import java.util.Date

/** The fasting timer: counts up live (a Chronometer) with time to the goal. */
class FastingWidget : HomeWidgetProvider() {
    companion object {
        private const val PURPLE = 0xFF8C7BFF.toInt()
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
        val start = data.value("fastStart")
        val goalMin = data.value("fastGoalMin").coerceAtLeast(1)
        val label = data.text("fastLabel") ?: "16:8"
        val now = System.currentTimeMillis()
        val fasting = start in 1..now
        val elapsedMs = if (fasting) now - start else 0L
        val goalMs = goalMin * 60_000L
        // Redraw when the goal is reached, to show it.
        WidgetRefresh.at(context, javaClass, if (fasting) start + goalMs else null)
        val goal = hours(goalMin)
        val open = WidgetLink.open(context, "health://fasting")
        val theme = WidgetTheme(context, data, PURPLE)
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.widget_fasting).apply {
                setTextViewText(R.id.title, "Fasting · $label")
                if (fasting) {
                    setViewVisibility(R.id.timer, View.VISIBLE)
                    setViewVisibility(R.id.idle, View.GONE)
                    // Chronometer time is relative to elapsedRealtime.
                    setChronometer(R.id.timer, SystemClock.elapsedRealtime() - elapsedMs, null, true)
                    val end = DateFormat.getTimeInstance(DateFormat.SHORT).format(Date(start + goalMs))
                    setTextViewText(
                        R.id.detail,
                        if (elapsedMs >= goalMs) "Goal reached · $goal" else "Ends $end",
                    )
                    setProgressBar(R.id.progress, 100, ((elapsedMs * 100) / goalMs).toInt().coerceAtMost(100), false)
                } else {
                    setChronometer(R.id.timer, SystemClock.elapsedRealtime(), null, false)
                    setViewVisibility(R.id.timer, View.GONE)
                    setViewVisibility(R.id.idle, View.VISIBLE)
                    setTextViewText(
                        R.id.detail,
                        if (goalMin % 60 == 0L) "Tap to start a ${goalMin / 60}-hour fast" else "Tap to start a $goal fast",
                    )
                    setProgressBar(R.id.progress, 100, 0, false)
                }
                theme.apply(
                    this,
                    R.id.root,
                    labels = intArrayOf(R.id.timer, R.id.idle),
                    secondaries = intArrayOf(R.id.detail),
                    accents = intArrayOf(R.id.title),
                    icons = intArrayOf(R.id.icon),
                    bars = intArrayOf(R.id.progress),
                )
                setOnClickPendingIntent(R.id.root, open)
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    /** "16 h", or "13 h 30 min" for a goal that isn't whole hours. */
    private fun hours(minutes: Long): String =
        if (minutes % 60 == 0L) "${minutes / 60} h" else "${minutes / 60} h ${minutes % 60} min"
}
