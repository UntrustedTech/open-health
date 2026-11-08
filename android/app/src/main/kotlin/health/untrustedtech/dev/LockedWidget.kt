package health.untrustedtech.dev

import android.appwidget.AppWidgetManager
import android.content.Context
import android.widget.RemoteViews

/** The lock card every widget shows instead of data while App Lock is on. */
object LockedWidget {
    /** Draws the lock card and returns true if the widgets are hidden. */
    fun showIfHidden(
        context: Context,
        manager: AppWidgetManager,
        ids: IntArray,
        data: WidgetData,
    ): Boolean {
        if (!data.hidden()) return false
        val open = WidgetLink.open(context, "health://summary")
        val theme = WidgetTheme(context, data, 0)
        ids.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.widget_locked).apply {
                theme.apply(this, R.id.root, secondaries = intArrayOf(R.id.message))
                setInt(R.id.icon, "setColorFilter", theme.secondary)
                setOnClickPendingIntent(R.id.root, open)
            }
            manager.updateAppWidget(id, views)
        }
        return true
    }
}
