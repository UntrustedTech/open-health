package health.untrustedtech.dev

import android.content.SharedPreferences
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Reads the values the app saves for the home screen widgets. */
class WidgetData(private val prefs: SharedPreferences) {
    private val todayText: String =
        SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())

    /** Values belong to [date]; after midnight the widgets show zeros. */
    private val isToday: Boolean = prefs.getString("date", null) == todayText

    /** Dart sends small numbers as Int and large ones as Long. */
    private fun number(key: String): Long = try {
        prefs.getInt(key, 0).toLong()
    } catch (e: ClassCastException) {
        prefs.getLong(key, 0L)
    }

    /** Today's value, or 0 if the saved data is from an earlier day. */
    fun today(key: String): Long = if (isToday) number(key) else 0L

    /** True while App Lock hides the widgets' data. */
    fun hidden(): Boolean = prefs.getBoolean("hidden", false)

    /** Goals don't reset at midnight. */
    fun value(key: String): Long = number(key)

    /**
     * Today's water. It has its own date, as the widget's button can add
     * water without the app.
     */
    fun water(): Long {
        // Until the app first saves "waterDate" (just after an update), the
        // shared date stands in for it.
        val date = prefs.getString("waterDate", null) ?: prefs.getString("date", null)
        return if (date == todayText) number("water") else 0L
    }

    /** A this-week value, or 0 once the saved week has ended. */
    fun thisWeek(key: String): Long {
        val ends = prefs.getString("weekEnds", null) ?: return number(key)
        // yyyy-MM-dd text sorts in date order.
        return if (todayText < ends) number(key) else 0L
    }

    /** Text prepared by the app (in the user's units), if saved. */
    fun text(key: String): String? = prefs.getString(key, null)

    /** Water in the user's units: "1,250" ml or "42.3" fl oz. */
    fun waterAmount(ml: Long): String =
        if (prefs.getBoolean("imperial", false)) "%,.1f".format(ml / 29.5735295625)
        else "%,d".format(ml)

    /** A colour the app saved, or null if it hasn't. */
    fun colour(key: String): Int? = if (prefs.contains(key)) number(key).toInt() else null

    /** The user's theme colour when themed widgets are on, else null. */
    fun accent(): Int? = if (prefs.contains("accent")) number("accent").toInt() else null

    fun progress(key: String, goal: String): Float {
        val g = value(goal)
        return if (g <= 0) 0f else today(key).toFloat() / g
    }
}
