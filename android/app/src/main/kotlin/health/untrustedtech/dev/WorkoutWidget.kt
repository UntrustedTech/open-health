package health.untrustedtech.dev

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/** This week's workout minutes with quick-start buttons. */
class WorkoutWidget : HomeWidgetProvider() {
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
        val minutes = data.thisWeek("weekMinutes")
        // Zero means the user turned the weekly goal off.
        val rawGoal = data.value("weekGoal")
        val goal = rawGoal.coerceAtLeast(1)
        val streak = data.value("streak")
        fun start(type: String) = WidgetLink.open(context, "health://workout/start?type=$type")
        val theme = WidgetTheme(context, data, GREEN)
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.widget_workout).apply {
                setTextViewText(
                    R.id.minutes,
                    if (rawGoal > 0) "$minutes/$goal min" else "$minutes min",
                )
                setTextViewText(
                    R.id.detail,
                    "${data.thisWeek("weekCount")} workouts" +
                        if (streak > 1) " · $streak-day streak" else "",
                )
                setProgressBar(R.id.progress, 100, ((minutes * 100) / goal).toInt().coerceAtMost(100), false)
                setViewVisibility(R.id.progress, if (rawGoal > 0) View.VISIBLE else View.GONE)
                theme.apply(
                    this,
                    R.id.root,
                    labels = intArrayOf(R.id.minutes),
                    secondaries = intArrayOf(R.id.detail),
                    accents = intArrayOf(R.id.title, R.id.run_text, R.id.strength_text),
                    icons = intArrayOf(R.id.icon, R.id.run_icon, R.id.strength_icon),
                    pills = intArrayOf(R.id.run, R.id.strength),
                    bars = intArrayOf(R.id.progress),
                )
                setContentDescription(R.id.run, "Start a run")
                setContentDescription(R.id.strength, "Start strength training")
                setOnClickPendingIntent(R.id.run, start("run"))
                setOnClickPendingIntent(R.id.strength, start("strength"))
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
