package health.untrustedtech.dev

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetProvider

/** Today's water with a one-tap "+250 ml" button. */
class WaterWidget : HomeWidgetProvider() {
    companion object {
        private const val WATER = 0xFF2FA8E6.toInt()
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
        val water = data.water()
        val goal = data.value("waterGoal").coerceAtLeast(1)
        // Runs in the background without opening the app.
        val add = HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("health://addwater"))
        val open = WidgetLink.open(context, "health://summary")
        val theme = WidgetTheme(context, data, WATER)
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.widget_water).apply {
                // Formatted here from the live total, so taps show at once.
                setTextViewText(R.id.amount, data.waterAmount(water))
                setTextViewText(R.id.goal, data.text("waterGoalText") ?: "of %,d ml".format(goal))
                // The button has a plus icon of its own.
                data.text("waterButton")?.let {
                    setTextViewText(R.id.add_text, it.removePrefix("+").trim())
                    setContentDescription(R.id.add, "Add ${it.removePrefix("+").trim()} of water")
                }
                theme.apply(
                    this,
                    R.id.root,
                    labels = intArrayOf(R.id.amount),
                    secondaries = intArrayOf(R.id.goal),
                    accents = intArrayOf(R.id.title, R.id.add_text),
                    icons = intArrayOf(R.id.icon, R.id.add_icon),
                    pills = intArrayOf(R.id.add),
                    bars = intArrayOf(R.id.progress),
                )
                setProgressBar(R.id.progress, 100, ((water * 100) / goal).toInt().coerceAtMost(100), false)
                setOnClickPendingIntent(R.id.add, add)
                setOnClickPendingIntent(R.id.root, open)
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
