package health.untrustedtech.dev

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import java.util.Calendar

// Widgets redraw every 30 minutes on their own; these wake one sooner when
// what it shows changes at a known time (a new day, a fast's goal). The
// alarms are inexact, so no exact-alarm permission is needed, and setting
// one again replaces it.
object WidgetRefresh {
    private const val MIDNIGHT = 0
    private const val AT_TIME = 1

    /** Redraws [widget] just after the next midnight. */
    fun atMidnight(context: Context, widget: Class<*>) {
        val next = Calendar.getInstance().apply {
            add(Calendar.DAY_OF_YEAR, 1)
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 5)
            set(Calendar.MILLISECOND, 0)
        }
        schedule(context, widget, MIDNIGHT, next.timeInMillis)
    }

    /** Redraws [widget] at [millis], or cancels that when it's null. */
    fun at(context: Context, widget: Class<*>, millis: Long?) {
        if (millis == null || millis <= System.currentTimeMillis()) {
            alarms(context).cancel(intent(context, widget, AT_TIME))
            return
        }
        schedule(context, widget, AT_TIME, millis)
    }

    private fun schedule(context: Context, widget: Class<*>, kind: Int, millis: Long) {
        alarms(context).set(AlarmManager.RTC, millis, intent(context, widget, kind))
    }

    private fun alarms(context: Context) =
        context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    private fun intent(context: Context, widget: Class<*>, kind: Int): PendingIntent {
        val ids = AppWidgetManager.getInstance(context)
            .getAppWidgetIds(ComponentName(context, widget))
        val update = Intent(context, widget)
            .setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE)
            .putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
        return PendingIntent.getBroadcast(
            context,
            widget.name.hashCode() * 2 + kind,
            update,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
