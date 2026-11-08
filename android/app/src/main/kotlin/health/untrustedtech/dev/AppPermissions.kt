package health.untrustedtech.dev

import android.app.Activity
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.content.pm.PermissionInfo
import android.os.Build
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

// "Erase All Data": gives back every runtime permission the app holds
// (location, notifications, Bluetooth, camera, ...), so the next launch
// asks again like a fresh install. Android 13+ only; Android removes them
// once the app's process ends, so "close" ends it.
class AppPermissions(private val activity: Activity) : MethodChannel.MethodCallHandler {
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "revokeAll" -> result.success(revokeAll())
            "close" -> {
                result.success(null)
                activity.finishAndRemoveTask()
            }
            else -> result.notImplemented()
        }
    }

    /// Whether any were given back (they go when the app closes).
    private fun revokeAll(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return false
        return try {
            val granted = granted()
            if (granted.isEmpty()) return false
            activity.revokeSelfPermissionsOnKill(granted)
            true
        } catch (e: RuntimeException) {
            Log.w("AppPermissions", "Could not revoke", e)
            false
        }
    }

    /// Runtime ("dangerous") permissions the app holds now.
    private fun granted(): List<String> {
        val pm = activity.packageManager
        val info: PackageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.getPackageInfo(
                activity.packageName,
                PackageManager.PackageInfoFlags.of(PackageManager.GET_PERMISSIONS.toLong()),
            )
        } else {
            @Suppress("DEPRECATION")
            pm.getPackageInfo(activity.packageName, PackageManager.GET_PERMISSIONS)
        }
        val names = info.requestedPermissions.orEmpty()
        val flags = info.requestedPermissionsFlags ?: IntArray(0)
        return names.indices.filter { i ->
            i < flags.size &&
                flags[i] and PackageInfo.REQUESTED_PERMISSION_GRANTED != 0 &&
                isRuntime(pm, names[i])
        }.map { names[it] }
    }

    private fun isRuntime(pm: PackageManager, name: String): Boolean = try {
        pm.getPermissionInfo(name, 0).protection == PermissionInfo.PROTECTION_DANGEROUS
    } catch (e: PackageManager.NameNotFoundException) {
        false
    }

    companion object {
        const val CHANNEL = "health/permissions"
    }
}
