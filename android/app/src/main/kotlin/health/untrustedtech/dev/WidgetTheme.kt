package health.untrustedtech.dev

import android.content.Context
import android.content.res.ColorStateList
import android.content.res.Configuration
import android.os.Build
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
import androidx.core.graphics.ColorUtils

/**
 * The app's look on a widget: its surface, text and accent, in the light
 * or dark the app uses. Each widget has its own colour (water blue, the
 * Fitness green); the user's accent replaces it when themed widgets are on.
 */
class WidgetTheme(context: Context, private val data: WidgetData, ownColour: Int) {
    private val dark: Boolean = when (data.value("wMode")) {
        1L -> false
        2L -> true
        else -> context.resources.configuration.uiMode and
            Configuration.UI_MODE_NIGHT_MASK == Configuration.UI_MODE_NIGHT_YES
    }

    private fun pick(light: String, night: String, fallback: Int): Int =
        data.colour(if (dark) night else light) ?: fallback

    val background = pick("wBgL", "wBgD", ContextCompat.getColor(context, R.color.widget_background))
    val label = pick("wLabelL", "wLabelD", ContextCompat.getColor(context, R.color.widget_text))
    val secondary = pick("wSecL", "wSecD", ContextCompat.getColor(context, R.color.widget_secondary))
    val accent = pick("wAccentL", "wAccentD", data.accent() ?: ownColour)

    /** A faint wash of the text colour, for empty tracks and cells. */
    val track: Int = ColorUtils.setAlphaComponent(label, 0x24)

    /** Capsule buttons: a soft wash of the accent. */
    private val wash: Int = ColorUtils.setAlphaComponent(accent, if (dark) 0x38 else 0x24)

    /** Colours the widget's surface, text, icons, buttons and bars. */
    fun apply(
        views: RemoteViews,
        root: Int,
        labels: IntArray = intArrayOf(),
        secondaries: IntArray = intArrayOf(),
        accents: IntArray = intArrayOf(),
        icons: IntArray = intArrayOf(),
        pills: IntArray = intArrayOf(),
        bars: IntArray = intArrayOf(),
    ) {
        val tints = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S
        if (tints) tint(views, root, "setBackgroundTintList", background)
        labels.forEach { views.setTextColor(it, label) }
        secondaries.forEach { views.setTextColor(it, secondary) }
        accents.forEach { views.setTextColor(it, accent) }
        icons.forEach { views.setInt(it, "setColorFilter", accent) }
        if (!tints) return
        pills.forEach { tint(views, it, "setBackgroundTintList", wash) }
        bars.forEach {
            tint(views, it, "setProgressTintList", accent)
            tint(views, it, "setProgressBackgroundTintList", track)
        }
    }

    private fun tint(views: RemoteViews, id: Int, method: String, colour: Int) =
        views.setColorStateList(id, method, ColorStateList.valueOf(colour))
}
