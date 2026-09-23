package com.saxify.app

import android.app.Activity
import android.content.ClipData
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.media.audiofx.Equalizer
import android.net.Uri
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import android.os.PowerManager
import java.io.File
import java.io.FileInputStream
import kotlin.concurrent.thread

/**
 * Boot counter, scoped Downloads, share, and the system equalizer.
 * Does not create or replace the music player.
 */
class SaxifyBridge(private val activity: Activity) {
    private var equalizer: Equalizer? = null
    private var sessionId: Int = 0
    val localDownloads = LocalDownloader(activity.applicationContext)
    private var playbackLock: PowerManager.WakeLock? = null

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "bootState" -> result.success(SaxifyBoot.snapshot(activity))
                "markLaunchSuccess" -> {
                    SaxifyBoot.markSuccess(activity)
                    result.success(null)
                }
                "saveToDownloads" -> io(result) {
                    saveToDownloads(
                        call.argument<String>("sourcePath") ?: "",
                        call.argument<String>("displayName") ?: "track_saxify.mp3",
                        call.argument<String>("mime") ?: "audio/mpeg",
                    )
                }
                "deleteDownload" -> io(result) {
                    deleteDownload(call.argument<String>("uri"), call.argument<String>("path"))
                }
                "listDownloads" -> io(result) { listDownloads() }
                "shareFile" -> {
                    shareFile(
                        call.argument<String>("path"),
                        call.argument<String>("uri"),
                        call.argument<String>("mime") ?: "*/*",
                        call.argument<String>("title") ?: "Share",
                    )
                    result.success(null)
                }
                "openSupportEmail" -> {
                    result.success(openSupportEmail(
                        call.argument<String>("to") ?: "",
                        call.argument<String>("subject") ?: "",
                        call.argument<String>("body") ?: "",
                    ))
                }
                "openContent" -> {
                    openContent(
                        call.argument<String>("uri") ?: "",
                        call.argument<String>("mime") ?: "*/*",
                    )
                    result.success(null)
                }
                "localDownloaderHealth" -> io(result) { localDownloads.health() }
                "fetchLocalInfo" -> io(result) {
                    localDownloads.info(call.argument<String>("url") ?: "")
                }
                "downloadLocal" -> io(result) {
                    localDownloads.download(
                        call.argument<String>("url") ?: "",
                        call.argument<String>("jobId") ?: "",
                        call.argument<String>("kind") ?: "",
                        call.argument<String>("formatId"),
                        call.argument<Boolean>("formatHasAudio") == true,
                    )
                }
                "cancelLocal" -> result.success(
                    localDownloads.cancel(call.argument<String>("jobId") ?: "")
                )
                "isOnWifi" -> {
                    val manager = activity.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
                    val caps = manager.getNetworkCapabilities(manager.activeNetwork)
                    result.success(caps?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true ||
                        caps?.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) == true)
                }
                "setPlaybackWakeLock" -> {
                    setPlaybackWakeLock(call.argument<Boolean>("enabled") == true)
                    result.success(null)
                }
                "eqInit" -> result.success(eqInit(call.argument<Int>("sessionId") ?: 0))
                "eqSetEnabled" -> {
                    equalizer?.enabled = call.argument<Boolean>("enabled") == true
                    result.success(null)
                }
                "eqSetBand" -> {
                    val band = call.argument<Int>("band") ?: 0
                    val level = call.argument<Int>("level") ?: 0
                    equalizer?.setBandLevel(band.toShort(), level.toShort())
                    result.success(null)
                }
                "eqUsePreset" -> result.success(eqUsePreset(call.argument<String>("name") ?: ""))
                "eqRelease" -> {
                    releaseEq()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("saxify", e.message, null)
        }
    }

    private fun io(result: MethodChannel.Result, work: () -> Any?) {
        thread(name = "saxify-io") {
            try {
                val value = work()
                activity.runOnUiThread {
                    if (!activity.isDestroyed) result.success(value)
                }
            } catch (e: Exception) {
                activity.runOnUiThread {
                    if (!activity.isDestroyed) result.error("saxify", e.message, null)
                }
            }
        }
    }

    private fun saveToDownloads(sourcePath: String, displayName: String, mime: String): Map<String, Any?> {
        val src = File(sourcePath)
        if (!src.exists()) throw IllegalArgumentException("Source file is missing")
        return if (Build.VERSION.SDK_INT >= 29) {
            saveMediaStore(src, displayName, mime)
        } else {
            saveLegacy(src, displayName)
        }
    }

    private fun saveMediaStore(src: File, displayName: String, mime: String): Map<String, Any?> {
        val resolver = activity.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, displayName)
            put(MediaStore.MediaColumns.MIME_TYPE, mime)
            put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/Saxify")
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        val collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        val uri = resolver.insert(collection, values)
            ?: throw IllegalStateException("Could not create a Downloads entry")
        try {
            resolver.openOutputStream(uri)?.use { out ->
                FileInputStream(src).use { input -> input.copyTo(out) }
            } ?: throw IllegalStateException("Could not write the download")
            val done = ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) }
            resolver.update(uri, done, null, null)
        } catch (error: Exception) {
            resolver.delete(uri, null, null)
            throw error
        }
        return mapOf(
            "displayName" to displayName,
            "uri" to uri.toString(),
            "path" to src.absolutePath,
            "size" to src.length(),
            "modifiedMs" to System.currentTimeMillis(),
        )
    }

    @Suppress("DEPRECATION")
    private fun saveLegacy(src: File, displayName: String): Map<String, Any?> {
        val dir = File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
            "Saxify",
        )
        if (!dir.exists() && !dir.mkdirs()) {
            throw IllegalStateException("Could not create Download/Saxify")
        }
        val dest = uniqueFile(dir, displayName)
        src.copyTo(dest, overwrite = true)
        return mapOf(
            "displayName" to dest.name,
            "uri" to Uri.fromFile(dest).toString(),
            "path" to dest.absolutePath,
            "size" to dest.length(),
            "modifiedMs" to dest.lastModified(),
        )
    }

    private fun deleteDownload(uri: String?, path: String?): Boolean {
        var removed = false
        if (!uri.isNullOrEmpty() && uri.startsWith("content:")) {
            removed = activity.contentResolver.delete(Uri.parse(uri), null, null) > 0
        }
        // Android 9 and below return file: URIs for the public copy. Delete
        // only files in our own public Saxify folder, not arbitrary file URIs.
        if (!uri.isNullOrEmpty() && uri.startsWith("file:")) {
            val publicRoot = File(
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
                "Saxify",
            ).canonicalFile
            val publicFile = File(Uri.parse(uri).path ?: "").canonicalFile
            if (publicFile.parentFile == publicRoot && publicFile.exists()) {
                removed = publicFile.delete() || removed
            }
        }
        if (!path.isNullOrEmpty()) {
            val file = File(path)
            if (file.exists()) removed = file.delete() || removed
        }
        return removed
    }

    private fun listDownloads(): List<Map<String, Any?>> {
        if (Build.VERSION.SDK_INT < 29) {
            @Suppress("DEPRECATION")
            val dir = File(
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
                "Saxify",
            )
            if (!dir.exists()) return emptyList()
            return dir.listFiles()?.map { file ->
                mapOf(
                    "displayName" to file.name,
                    "path" to file.absolutePath,
                    "uri" to Uri.fromFile(file).toString(),
                    "size" to file.length(),
                    "modifiedMs" to file.lastModified(),
                )
            } ?: emptyList()
        }
        val collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        val projection = arrayOf(
            MediaStore.MediaColumns._ID,
            MediaStore.MediaColumns.DISPLAY_NAME,
            MediaStore.MediaColumns.SIZE,
            MediaStore.MediaColumns.DATE_MODIFIED,
            MediaStore.MediaColumns.RELATIVE_PATH,
        )
        val out = ArrayList<Map<String, Any?>>()
        activity.contentResolver.query(
            collection,
            projection,
            "${MediaStore.MediaColumns.RELATIVE_PATH} LIKE ?",
            arrayOf("%Saxify%"),
            "${MediaStore.MediaColumns.DATE_MODIFIED} DESC",
        )?.use { cursor ->
            val nameIdx = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DISPLAY_NAME)
            val sizeIdx = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.SIZE)
            val modIdx = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DATE_MODIFIED)
            val idIdx = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns._ID)
            while (cursor.moveToNext()) {
                val id = cursor.getLong(idIdx)
                val itemUri = Uri.withAppendedPath(collection, id.toString())
                out.add(
                    mapOf(
                        "displayName" to cursor.getString(nameIdx),
                        "uri" to itemUri.toString(),
                        "size" to cursor.getLong(sizeIdx),
                        "modifiedMs" to cursor.getLong(modIdx) * 1000,
                    ),
                )
            }
        }
        return out
    }

    private fun shareFile(path: String?, uri: String?, mime: String, title: String) {
        val shareUri = contentUri(path, uri)
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = mime
            putExtra(Intent.EXTRA_STREAM, shareUri)
            clipData = ClipData.newRawUri(title, shareUri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        activity.startActivity(Intent.createChooser(intent, title))
    }

    private fun openSupportEmail(to: String, subject: String, body: String): Boolean {
        val intent = Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:$to")).apply {
            putExtra(Intent.EXTRA_EMAIL, arrayOf(to))
            putExtra(Intent.EXTRA_SUBJECT, subject)
            putExtra(Intent.EXTRA_TEXT, body)
        }
        return try {
            activity.startActivity(intent)
            true
        } catch (_: android.content.ActivityNotFoundException) {
            false
        }
    }

    private fun openContent(raw: String, mime: String) {
        val uri = if (raw.startsWith("content:")) {
            Uri.parse(raw)
        } else {
            contentUri(if (raw.startsWith("file:")) Uri.parse(raw).path else raw, null)
        }
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, mime)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        activity.startActivity(intent)
    }

    private fun contentUri(path: String?, uri: String?): Uri {
        if (!uri.isNullOrEmpty() && uri.startsWith("content:")) return Uri.parse(uri)
        val file = File(path ?: throw IllegalArgumentException("No file to share"))
        return FileProvider.getUriForFile(activity, "${activity.packageName}.fileprovider", file)
    }

    private fun setPlaybackWakeLock(enabled: Boolean) {
        if (!enabled) {
            playbackLock?.let { if (it.isHeld) it.release() }
            playbackLock = null
            return
        }
        val lock = playbackLock ?: (activity.getSystemService(Context.POWER_SERVICE) as PowerManager)
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "Saxify:AudioPlayback").also {
                it.setReferenceCounted(false)
                playbackLock = it
            }
        if (!lock.isHeld) lock.acquire()
    }

    private fun eqInit(id: Int): Map<String, Any> {
        if (id == 0) return emptyEq()
        val current = equalizer
        if (current != null && sessionId == id) return snapshot(current)
        releaseEq()
        val created = Equalizer(0, id)
        created.enabled = true
        equalizer = created
        sessionId = id
        return snapshot(created)
    }

    private fun snapshot(eq: Equalizer): Map<String, Any> {
        val bands = eq.numberOfBands.toInt()
        val range = eq.bandLevelRange
        val centers = ArrayList<Int>(bands)
        val levels = ArrayList<Int>(bands)
        for (i in 0 until bands) {
            // Android Equalizer.getCenterFreq returns millihertz. Not getCenterFrecuencias.
            centers.add(eq.getCenterFreq(i.toShort()))
            levels.add(eq.getBandLevel(i.toShort()).toInt())
        }
        val presets = ArrayList<String>(eq.numberOfPresets.toInt())
        for (i in 0 until eq.numberOfPresets.toInt()) {
            presets.add(eq.getPresetName(i.toShort()))
        }
        return mapOf(
            "bands" to bands,
            "enabled" to eq.enabled,
            "min" to range[0].toInt(),
            "max" to range[1].toInt(),
            "centersMilliHz" to centers,
            "levels" to levels,
            "presets" to presets,
        )
    }

    private fun eqUsePreset(name: String): Boolean {
        val eq = equalizer ?: return false
        for (i in 0 until eq.numberOfPresets.toInt()) {
            if (eq.getPresetName(i.toShort()).equals(name, ignoreCase = true)) {
                eq.usePreset(i.toShort())
                return true
            }
        }
        return false
    }

    private fun releaseEq() {
        try {
            equalizer?.release()
        } catch (_: Exception) {
        }
        equalizer = null
        sessionId = 0
    }

    private fun emptyEq(): Map<String, Any> = mapOf(
        "bands" to 0,
        "enabled" to false,
        "min" to -1500,
        "max" to 1500,
        "centersMilliHz" to emptyList<Int>(),
        "levels" to emptyList<Int>(),
        "presets" to emptyList<String>(),
    )

    private fun uniqueFile(dir: File, name: String): File {
        var file = File(dir, name)
        if (!file.exists()) return file
        val dot = name.lastIndexOf('.')
        val base = if (dot > 0) name.substring(0, dot) else name
        val ext = if (dot > 0) name.substring(dot) else ""
        var i = 2
        while (file.exists() && i < 40) {
            file = File(dir, "$base ($i)$ext")
            i++
        }
        return file
    }

}
