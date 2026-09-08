package com.example.smart_ledger

import android.content.ContentResolver
import android.content.ContentUris
import android.content.Context
import android.content.pm.PackageManager
import android.database.ContentObserver
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import androidx.core.content.ContextCompat
import java.io.File
import java.io.FileOutputStream

/**
 * 截屏监听：通过 ContentObserver 监听系统媒体库，检测到新的截图时
 * 将其复制到应用缓存目录并回调给 Flutter 侧做 OCR 识别。
 *
 * 说明：
 * - 需要存储读取权限（Android 13+ READ_MEDIA_IMAGES，更低版本 READ_EXTERNAL_STORAGE）
 * - 仅在应用进程存活时有效（后台常驻受系统限制，属平台行为，建议加入后台白名单）
 * - 检测窗口 30 秒（部分机型媒体入库有延迟）；目录不匹配时兜底处理最新新增图片，
 *   由 OCR 判定是否为账单（识别不到金额会静默忽略，不会误记）
 */
object ScreenshotWatcher {
    /** 检测窗口：过短会漏掉入库慢的机型 */
    private const val SCREENSHOT_WINDOW_MS = 30000L

    /** 兜底处理：即便目录不匹配，也会尝试最新一张新增图片（OCR 兜底判定） */
    private const val FALLBACK_LATEST = true

    private var observer: ContentObserver? = null
    private var contextRef: Context? = null
    private var callback: ((String) -> Unit)? = null
    private var watching = false

    /** 已处理的最新图片 id，防止同一次截图被重复识别 */
    private var lastProcessedId = -1L

    fun isActive(): Boolean = watching

    /** 开始监听。返回 started / no_permission */
    fun start(context: Context, cb: (String) -> Unit): String {
        contextRef = context.applicationContext
        callback = cb
        lastProcessedId = -1L
        if (!hasPermission(context)) return "no_permission"
        register(context)
        return "started"
    }

    /** 权限授予后由 MainActivity 回调，注册监听 */
    fun onPermissionGranted(context: Context) {
        if (!watching) register(context)
    }

    fun stop(context: Context) {
        observer?.let { context.contentResolver.unregisterContentObserver(it) }
        observer = null
        watching = false
        callback = null
        contextRef = null
    }

    private fun register(context: Context) {
        if (observer != null) return
        observer = object : ContentObserver(Handler(Looper.getMainLooper())) {
            override fun onChange(selfChange: Boolean) {
                handleChange()
            }
        }
        context.contentResolver.registerContentObserver(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            true,
            observer!!
        )
        watching = true
    }

    private fun handleChange() {
        val ctx = contextRef ?: return
        val cb = callback ?: return
        val resolver = ctx.contentResolver

        val cutoffSec = (System.currentTimeMillis() - SCREENSHOT_WINDOW_MS) / 1000
        val selection = "${MediaStore.Images.Media.DATE_ADDED} >= ?"
        val args = arrayOf(cutoffSec.toString())
        val projection = arrayOf(
            MediaStore.Images.Media._ID,
            MediaStore.Images.Media.RELATIVE_PATH,
        )

        try {
            resolver.query(
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                projection,
                selection,
                args,
                "${MediaStore.Images.Media.DATE_ADDED} DESC"
            )?.use { c ->
                if (!c.moveToFirst()) return
                // RELATIVE_PATH 仅 Android 10+ 存在；低版本无该列时直接候选
                val relIdx = c.getColumnIndex(MediaStore.Images.Media.RELATIVE_PATH)
                var candidateId = -1L
                if (relIdx < 0) {
                    candidateId = c.getLong(c.getColumnIndexOrThrow(MediaStore.Images.Media._ID))
                } else {
                    var idx = 0
                    var matched = false
                    do {
                        val rel = c.getString(relIdx) ?: ""
                        val isScreenshot = rel.contains("Screenshot", ignoreCase = true) ||
                            rel.contains("截屏") ||
                            rel.contains("截图")
                        val id = c.getLong(c.getColumnIndexOrThrow(MediaStore.Images.Media._ID))
                        if (isScreenshot) {
                            candidateId = id
                            matched = true
                            break
                        }
                        idx++
                    } while (c.moveToNext() && idx < 3)
                    // 兜底：窗口内没有匹配目录的图片时，也尝试最新一张
                    if (!matched && FALLBACK_LATEST) {
                        candidateId = c.getLong(c.getColumnIndexOrThrow(MediaStore.Images.Media._ID))
                    }
                }
                if (candidateId > 0 && candidateId != lastProcessedId) {
                    lastProcessedId = candidateId
                    copyToCache(ctx, resolver, candidateId)?.let { path ->
                        cb(path)
                    }
                }
            }
        } catch (e: Exception) {
            // 无权限/安全异常：不崩溃，等用户授权后重试
        }
    }

    /** 用 ContentResolver 流式复制到缓存目录（不依赖 DATA 列，兼容分区存储） */
    private fun copyToCache(ctx: Context, resolver: ContentResolver, id: Long): String? {
        return try {
            val src = ContentUris.withAppendedId(
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI, id
            )
            val input = resolver.openInputStream(src) ?: return null
            val file = File(ctx.cacheDir, "screenshot_${System.currentTimeMillis()}.jpg")
            input.use { ins ->
                FileOutputStream(file).use { out -> ins.copyTo(out) }
            }
            file.absolutePath
        } catch (e: Exception) {
            null
        }
    }

    private fun hasPermission(ctx: Context): Boolean {
        val perm = if (Build.VERSION.SDK_INT >= 33)
            android.Manifest.permission.READ_MEDIA_IMAGES
        else
            android.Manifest.permission.READ_EXTERNAL_STORAGE
        return ContextCompat.checkSelfPermission(ctx, perm) == PackageManager.PERMISSION_GRANTED
    }
}
