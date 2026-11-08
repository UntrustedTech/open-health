package health.untrustedtech.dev

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/** Today's Move, Exercise and Steps rings. */
class ActivityWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val data = WidgetData(widgetData)
        WidgetRefresh.atMidnight(context, javaClass)
        if (LockedWidget.showIfHidden(context, appWidgetManager, appWidgetIds, data)) return
        val size = (context.resources.displayMetrics.density * 96).toInt()
        val rings = RingRenderer.draw(
            size,
            listOf(
                data.progress("move", "moveGoal"),
                data.progress("exercise", "exerciseGoal"),
                data.progress("steps", "stepsGoal"),
            ),
            listOf(RingRenderer.MOVE, RingRenderer.EXERCISE, RingRenderer.STEPS),
        )
        val open = WidgetLink.open(context, "health://summary")
        val theme = WidgetTheme(context, data, RingRenderer.MOVE)
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.widget_activity).apply {
                setImageViewBitmap(R.id.rings, rings)
                setTextViewText(R.id.move, "%,d/%,d Cal".format(data.today("move"), data.value("moveGoal")))
                setTextViewText(R.id.exercise, "%,d/%,d min".format(data.today("exercise"), data.value("exerciseGoal")))
                setTextViewText(R.id.steps, "%,d".format(data.today("steps")))
                // The rings keep their own colours, as Apple's do.
                theme.apply(this, R.id.root, labels = intArrayOf(R.id.move, R.id.exercise, R.id.steps))
                setOnClickPendingIntent(R.id.root, open)
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
