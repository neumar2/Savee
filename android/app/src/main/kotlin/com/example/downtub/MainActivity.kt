package com.example.downtub

import android.content.Intent
import android.media.MediaScannerConnection
import android.net.Uri
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.savee/media_scanner"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "scanFile" -> {
                    val filePath = call.argument<String>("path")
                    if (filePath != null) {
                        MediaScannerConnection.scanFile(
                            applicationContext,
                            arrayOf(filePath),
                            null
                        ) { path, uri ->
                            println("Scanned $path -> uri=$uri")
                        }
                        result.success(true)
                    } else {
                        result.error("INVALID_PATH", "O caminho do arquivo é nulo", null)
                    }
                }
                "openFile" -> {
                    val filePath = call.argument<String>("path")
                    val mimeType = call.argument<String>("mimeType")
                    if (filePath != null) {
                        try {
                            val file = File(filePath)
                            val uri = Uri.parse(file.absolutePath)
                            val intent = Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(uri, mimeType ?: "*/*")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("CANNOT_OPEN", e.message, null)
                        }
                    } else {
                        result.error("INVALID_PATH", "Caminho nulo", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}

