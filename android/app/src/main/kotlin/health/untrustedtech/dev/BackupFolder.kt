package health.untrustedtech.dev

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Lets the user pick a folder once (Google Drive, Downloads, an SD card…)
 * and lets the app write backup files there later, through Android's
 * Storage Access Framework. Only files this app names "Health Backup …"
 * are listed or deleted.
 */
class BackupFolder(private val activity: Activity) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "health/backup_folder"
        const val PICK_REQUEST = 4127
        private const val PREFIX = "Health Backup "
    }

    private var pending: MethodChannel.Result? = null

    /** File work (a backup can be megabytes, on a slow cloud folder) runs here. */
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "pick") {
            pick(result)
            return
        }
        val tree = call.argument<String>("tree")?.let(Uri::parse)
        val work: (() -> Any?)? = when (call.method) {
            "hasAccess" -> { -> hasAccess(tree!!) }
            "write" -> { ->
                write(tree!!, call.argument<String>("name")!!, call.argument<String>("text")!!)
            }
            "list" -> { -> list(tree!!) }
            "delete" -> { -> delete(Uri.parse(call.argument<String>("doc")!!)) }
            else -> null
        }
        if (work == null) {
            result.notImplemented()
            return
        }
        io.execute {
            try {
                val value = work()
                main.post { result.success(value) }
            } catch (e: Exception) {
                main.post { result.error("folder", e.message, null) }
            }
        }
    }

    private fun pick(result: MethodChannel.Result) {
        // A picker whose answer never came back (say the activity was
        // recreated meanwhile) mustn't block picking again.
        pending?.success(null)
        pending = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).addFlags(
            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
        )
        try {
            activity.startActivityForResult(intent, PICK_REQUEST)
        } catch (e: ActivityNotFoundException) {
            // No document picker on this device (or work profile).
            pending = null
            result.error("no-picker", "No folder picker is available", null)
        }
    }

    /** Called from the activity with the picker's result. */
    fun onPicked(resultCode: Int, data: Intent?) {
        val result = pending ?: return
        pending = null
        val tree = data?.data
        if (resultCode != Activity.RESULT_OK || tree == null) {
            result.success(null)
            return
        }
        try {
            activity.contentResolver.takePersistableUriPermission(
                tree,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
            )
            result.success(mapOf("tree" to tree.toString(), "name" to displayName(tree)))
        } catch (e: Exception) {
            result.error("folder", e.message, null)
        }
    }

    private fun hasAccess(tree: Uri): Boolean =
        activity.contentResolver.persistedUriPermissions.any {
            it.uri == tree && it.isWritePermission
        }

    private fun rootDoc(tree: Uri): Uri =
        DocumentsContract.buildDocumentUriUsingTree(
            tree,
            DocumentsContract.getTreeDocumentId(tree),
        )

    private fun displayName(tree: Uri): String {
        activity.contentResolver.query(
            rootDoc(tree),
            arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME),
            null,
            null,
            null,
        )?.use { c -> if (c.moveToFirst()) return c.getString(0) }
        return "Selected folder"
    }

    private fun write(tree: Uri, name: String, text: String): String {
        require(name.startsWith(PREFIX)) { "Unexpected file name" }
        val doc = DocumentsContract.createDocument(
            activity.contentResolver,
            rootDoc(tree),
            "application/json",
            name,
        ) ?: throw IllegalStateException("Could not create the file")
        activity.contentResolver.openOutputStream(doc, "w")?.use { out ->
            out.write(text.toByteArray(Charsets.UTF_8))
        } ?: throw IllegalStateException("Could not open the file")
        return doc.toString()
    }

    /** Deletes [doc], but only a file this app named "Health Backup …". */
    private fun delete(doc: Uri): Boolean {
        var name: String? = null
        activity.contentResolver.query(
            doc,
            arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME),
            null,
            null,
            null,
        )?.use { c -> if (c.moveToFirst()) name = c.getString(0) }
        require(name?.startsWith(PREFIX) == true) { "Not a Health backup" }
        return DocumentsContract.deleteDocument(activity.contentResolver, doc)
    }

    private fun list(tree: Uri): List<Map<String, Any>> {
        val children = DocumentsContract.buildChildDocumentsUriUsingTree(
            tree,
            DocumentsContract.getTreeDocumentId(tree),
        )
        val out = mutableListOf<Map<String, Any>>()
        activity.contentResolver.query(
            children,
            arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                DocumentsContract.Document.COLUMN_LAST_MODIFIED,
            ),
            null,
            null,
            null,
        )?.use { c ->
            while (c.moveToNext()) {
                val name = c.getString(1) ?: continue
                if (!name.startsWith(PREFIX)) continue
                out.add(
                    mapOf(
                        "doc" to DocumentsContract.buildDocumentUriUsingTree(tree, c.getString(0)).toString(),
                        "name" to name,
                        "modified" to c.getLong(2),
                    ),
                )
            }
        }
        return out
    }
}
