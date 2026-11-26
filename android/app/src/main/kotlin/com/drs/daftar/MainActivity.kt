package com.drs.daftar

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "daftar/files")
            .setMethodCallHandler { call, result ->
                if (call.method == "saveToDownloads") {
                    try {
                        val bytes = call.argument<ByteArray>("bytes")!!
                        val name = call.argument<String>("name")!!
                        val mime = call.argument<String>("mime") ?: "application/pdf"
                        result.success(saveToDownloads(bytes, name, mime))
                    } catch (e: Exception) {
                        result.error("SAVE_FAILED", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    /** يحفظ الملف في مجلد التنزيلات العام ويعيد وصفاً للمسار. */
    private fun saveToDownloads(bytes: ByteArray, name: String, mime: String): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, name)
                put(MediaStore.Downloads.MIME_TYPE, mime)
                put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/Daftar")
            }
            val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw Exception("insert failed")
            contentResolver.openOutputStream(uri)!!.use { it.write(bytes) }
            return "Download/Daftar/" + name
        } else {
            val dir = File(Environment.getExternalStoragePublicDirectory(
                Environment.DIRECTORY_DOWNLOADS), "Daftar")
            dir.mkdirs()
            File(dir, name).writeBytes(bytes)
            return "Download/Daftar/" + name
        }
    }
}
