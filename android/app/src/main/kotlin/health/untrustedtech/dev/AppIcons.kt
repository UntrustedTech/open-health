package health.untrustedtech.dev

import android.app.Activity
import android.content.ComponentName
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Build
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

// The app's launcher icon (Appearance → App Icon). Each icon is a launcher
// entry in AndroidManifest.xml (".IconDefault", ".IconMixBlackWhite", ...,
// written by tool/make_app_icons.py) and only the chosen one is enabled. Launchers redraw, and some restart the app,
// when that changes, so the switch waits until the app is left (onStop).
class AppIcons(private val activity: Activity) : MethodChannel.MethodCallHandler {
    private var pending: String? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "set" -> {
                val name = call.arguments as? String
                if (name == null || name !in names) {
                    result.success(false)
                    return
                }
                pending = if (name == current()) null else name
                result.success(true)
            }
            "current" -> result.success(current())
            "picture" -> {
                val name = call.arguments as? String
                result.success(if (name != null && name in names) picture(name) else null)
            }
            else -> result.notImplemented()
        }
    }

    /// Switches to the chosen icon, if it changed. Kept for next time if
    /// Android refuses.
    fun applyPending() {
        val name = pending ?: return
        val pm = activity.packageManager
        try {
            // The new one first, so there's always an icon to open the app
            // from. Only those that change are touched: there are dozens.
            for (n in listOf(name) + names.filter { it != name }) {
                val state = if (n == name) PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                else PackageManager.COMPONENT_ENABLED_STATE_DISABLED
                if (isEnabled(n) == (n == name)) continue
                pm.setComponentEnabledSetting(component(n), state, PackageManager.DONT_KILL_APP)
            }
            pending = null
        } catch (e: RuntimeException) {
            Log.w("AppIcons", "Could not switch to $name", e)
        }
    }

    /// [name]'s launcher icon drawn into a PNG for notifications to show;
    /// its path, or null if it couldn't be drawn.
    private fun picture(name: String): String? = try {
        val pm = activity.packageManager
        val flags = PackageManager.MATCH_DISABLED_COMPONENTS
        val info = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.getActivityInfo(component(name), PackageManager.ComponentInfoFlags.of(flags.toLong()))
        } else {
            @Suppress("DEPRECATION")
            pm.getActivityInfo(component(name), flags)
        }
        val icon = info.loadIcon(pm)
        val bitmap = Bitmap.createBitmap(PICTURE_SIZE, PICTURE_SIZE, Bitmap.Config.ARGB_8888)
        icon.setBounds(0, 0, PICTURE_SIZE, PICTURE_SIZE)
        icon.draw(Canvas(bitmap))
        val file = File(activity.cacheDir, "notification_icon_$name.png")
        file.outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
        file.path
    } catch (e: Exception) {
        Log.w("AppIcons", "Could not draw $name", e)
        null
    }

    /// The icon in use: the enabled entry, or "Default" as the manifest has it.
    private fun current(): String = names.firstOrNull { isEnabled(it) } ?: DEFAULT

    /// Whether [name] is on, either set so or as the manifest has it.
    private fun isEnabled(name: String): Boolean =
        when (activity.packageManager.getComponentEnabledSetting(component(name))) {
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> true
            PackageManager.COMPONENT_ENABLED_STATE_DEFAULT -> name == DEFAULT
            else -> false
        }

    /// Every icon's name, read from the manifest's launcher entries.
    private val names: List<String> by lazy {
        val prefix = "$PACKAGE.Icon"
        val flags = PackageManager.GET_ACTIVITIES or PackageManager.MATCH_DISABLED_COMPONENTS
        val info = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            activity.packageManager.getPackageInfo(
                activity.packageName,
                PackageManager.PackageInfoFlags.of(flags.toLong()),
            )
        } else {
            @Suppress("DEPRECATION")
            activity.packageManager.getPackageInfo(activity.packageName, flags)
        }
        info.activities.orEmpty()
            .map { it.name }
            .filter { it.startsWith(prefix) }
            .map { it.removePrefix(prefix) }
    }

    private fun component(name: String) =
        ComponentName(activity.packageName, "$PACKAGE.Icon$name")

    companion object {
        const val CHANNEL = "health/icon"
        private const val DEFAULT = "Default"
        private const val PICTURE_SIZE = 192
        private val PACKAGE = MainActivity::class.java.`package`!!.name
    }
}
