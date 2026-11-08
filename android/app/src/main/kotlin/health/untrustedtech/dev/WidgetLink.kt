package health.untrustedtech.dev

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Base64
import java.security.MessageDigest
import java.security.SecureRandom

// Widget taps open the app with a "health://" link. MainActivity is the
// launcher, so any app could send it the same link; a per-install secret
// that only this app's widgets carry tells real taps apart.
object WidgetLink {
    const val ACTION = "es.antonborri.home_widget.action.LAUNCH"
    private const val EXTRA = "health.untrustedtech.dev.WIDGET_KEY"
    private const val PREFS = "widget_link"
    private const val KEY = "key"

    @Synchronized
    private fun secret(context: Context): String {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.getString(KEY, null)?.let { return it }
        val bytes = ByteArray(32).also { SecureRandom().nextBytes(it) }
        val key = Base64.encodeToString(bytes, Base64.NO_WRAP)
        prefs.edit().putString(KEY, key).commit()
        return key
    }

    /// Opens the app at [link] when the widget is tapped.
    fun open(context: Context, link: String): PendingIntent {
        val intent = Intent(context, MainActivity::class.java)
            .setAction(ACTION)
            .setData(Uri.parse(link))
            .putExtra(EXTRA, secret(context))
        return PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }

    /// True when [intent] came from one of this app's widgets.
    fun isFromWidget(context: Context, intent: Intent?): Boolean {
        if (intent?.action != ACTION || intent.data?.scheme != "health") return false
        val given = try {
            intent.getStringExtra(EXTRA)
        } catch (_: RuntimeException) {
            // Extras another app made unreadable on purpose.
            null
        } ?: return false
        return MessageDigest.isEqual(given.toByteArray(), secret(context).toByteArray())
    }
}
