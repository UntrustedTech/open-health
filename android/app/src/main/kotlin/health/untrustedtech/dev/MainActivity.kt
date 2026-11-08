package health.untrustedtech.dev

import android.content.ActivityNotFoundException
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity is required by the Health Connect permission flow.
class MainActivity : FlutterFragmentActivity() {
    private val backupFolder = BackupFolder(this)
    private val appIcons = AppIcons(this)

    // Health Connect opens the app with these actions when the user asks why
    // it needs access; show the privacy screen instead of the usual start.
    // Intent extras are never read.
    override fun getInitialRoute(): String? =
        if (isRationale(intent)) PRIVACY_ROUTE else super.getInitialRoute()

    private fun isRationale(intent: Intent?) = when (intent?.action) {
        "androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE",
        "android.intent.action.VIEW_PERMISSION_USAGE" -> true
        else -> false
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // After the process was killed, Android starts the activity again
        // with its first intent: a widget link already taken mustn't run
        // twice (e.g. start another workout).
        if (savedInstanceState?.getBoolean(LINK_TAKEN) == true) clearLink()
        super.onCreate(savedInstanceState)
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        outState.putBoolean(LINK_TAKEN, !WidgetLink.isFromWidget(this, intent))
    }

    // A widget tap while the app is running: keep the link so the app can
    // take it when it resumes (see "health/links"). Health Connect's "why
    // does it need access" opens the privacy screen over what's showing.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (isRationale(intent)) flutterEngine?.navigationChannel?.pushRoute(PRIVACY_ROUTE)
    }

    private fun clearLink() {
        intent?.let { setIntent(Intent(it).setAction(Intent.ACTION_MAIN).setData(null)) }
    }

    // Set while another screen is open for a result (Health Connect's
    // permissions, the backup folder picker): the app hasn't been left.
    private var awaitingResult = false

    @Deprecated("Overridden only to notice the app opening another screen")
    override fun startActivityForResult(intent: Intent, requestCode: Int, options: Bundle?) {
        awaitingResult = true
        super.startActivityForResult(intent, requestCode, options)
    }

    override fun onResume() {
        super.onResume()
        awaitingResult = false
    }

    // A new app icon takes over once the app is left (see AppIcons), not
    // while the user is in a flow the app started.
    override fun onStop() {
        super.onStop()
        if (!awaitingResult && !isChangingConfigurations) appIcons.applyPending()
    }

    @Deprecated("Needed for the folder picker's result")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == BackupFolder.PICK_REQUEST) backupFolder.onPicked(resultCode, data)
    }

    /// The Health Connect screen to open.
    private enum class HealthScreen { PERMISSIONS, DATA }

    /// Opens Health Connect at this app's permissions, or at its "Data and
    /// access" screen. Built into Android 14+; a separate app before that.
    /// Falls back to Health Connect's main page, and returns whether
    /// anything opened.
    private fun openHealthConnect(screen: HealthScreen): Boolean {
        val modern = Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE
        // The built-in actions first on Android 14+, then the app's; some
        // builds only answer one of them.
        fun ordered(builtIn: String, app: String) =
            if (modern) listOf(builtIn, app) else listOf(app, builtIn)
        val candidates = buildList {
            when (screen) {
                HealthScreen.PERMISSIONS -> for (action in ordered(
                    "android.health.connect.action.MANAGE_HEALTH_PERMISSIONS",
                    "androidx.health.ACTION_MANAGE_HEALTH_PERMISSIONS",
                )) {
                    add(Intent(action).putExtra(Intent.EXTRA_PACKAGE_NAME, packageName))
                }
                HealthScreen.DATA -> for (action in ordered(
                    "android.health.connect.action.MANAGE_HEALTH_DATA",
                    "androidx.health.ACTION_MANAGE_HEALTH_DATA",
                )) {
                    add(Intent(action))
                }
            }
            for (action in ordered(
                "android.health.connect.action.HEALTH_HOME_SETTINGS",
                "androidx.health.ACTION_HEALTH_CONNECT_SETTINGS",
            )) {
                add(Intent(action))
            }
        }
        for (intent in candidates) {
            try {
                startActivity(intent)
                return true
            } catch (_: ActivityNotFoundException) {
                // Try the next screen.
            } catch (_: SecurityException) {
                // Try the next screen.
            }
        }
        return false
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BackupFolder.CHANNEL)
            .setMethodCallHandler(backupFolder)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AppIcons.CHANNEL)
            .setMethodCallHandler(appIcons)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AppPermissions.CHANNEL)
            .setMethodCallHandler(AppPermissions(this))
        // Home screen widget links ("health://fasting"), taken once each, and
        // only from this app's own widgets (see WidgetLink).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "health/links")
            .setMethodCallHandler { call, result ->
                if (call.method == "take") {
                    val current = intent
                    if (WidgetLink.isFromWidget(this, current)) {
                        result.success(current?.data?.toString())
                        clearLink()
                    } else {
                        result.success(null)
                    }
                } else {
                    result.notImplemented()
                }
            }
        // Health Connect's own screens: this app's permissions, and its
        // "Data and access" screen.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "health/connect")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openPermissions" -> result.success(openHealthConnect(HealthScreen.PERMISSIONS))
                    "openData" -> result.success(openHealthConnect(HealthScreen.DATA))
                    else -> result.notImplemented()
                }
            }
        // "Hide in App Switcher": a secure window shows blank in recents and
        // can't be captured in screenshots.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "health/secure")
            .setMethodCallHandler { call, result ->
                if (call.method == "setSecure") {
                    if (call.arguments == true) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    }
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }

    private companion object {
        const val PRIVACY_ROUTE = "/privacy"
        const val LINK_TAKEN = "widgetLinkTaken"
    }
}
