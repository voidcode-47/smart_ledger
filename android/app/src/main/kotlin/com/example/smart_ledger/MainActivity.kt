package com.example.smart_ledger

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    companion object {
        const val CHANNEL = "smart_ledger/screenshot"
        private const val REQ_MEDIA = 1001
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startWatch" -> {
                        val requestIfNeeded = call.argument<Boolean>("request") ?: true
                        val status = ScreenshotWatcher.start(this) { path ->
                            runOnUiThread {
                                MethodChannel(
                                    flutterEngine.dartExecutor.binaryMessenger,
                                    CHANNEL
                                ).invokeMethod("onScreenshot", path)
                            }
                        }
                        if (status == "no_permission" && requestIfNeeded) {
                            requestMediaPermission()
                        }
                        result.success(status)
                    }
                    "stopWatch" -> {
                        ScreenshotWatcher.stop(this)
                        result.success(true)
                    }
                    "isWatching" -> result.success(ScreenshotWatcher.isActive())
                    "openAppSettings" -> {
                        try {
                            startActivity(
                                Intent(
                                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                    Uri.parse("package:$packageName")
                                )
                            )
                        } catch (_: Exception) {
                            // 个别 ROM 不支持跳转时忽略
                        }
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun requestMediaPermission() {
        val perm = if (Build.VERSION.SDK_INT >= 33)
            Manifest.permission.READ_MEDIA_IMAGES
        else
            Manifest.permission.READ_EXTERNAL_STORAGE
        ActivityCompat.requestPermissions(this, arrayOf(perm), REQ_MEDIA)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQ_MEDIA &&
            grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        ) {
            ScreenshotWatcher.onPermissionGranted(this)
        }
    }
}
