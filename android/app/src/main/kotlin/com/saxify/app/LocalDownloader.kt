package com.saxify.app

import android.content.Context
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import com.yausername.ffmpeg.FFmpeg
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLRequest
import java.io.File
import kotlin.math.max

/** Bundled yt-dlp + FFmpeg. All extraction, downloads and post-processing run
 * on the device; the only HTTP requests are to the media's own public host.
 * Never pass a shell command or an arbitrary output directory from Dart.
 */
class LocalDownloader(private val context: Context) : EventChannel.StreamHandler {
    private val main = android.os.Handler(android.os.Looper.getMainLooper())
    private var events: EventChannel.EventSink? = null
    private val cancelled = java.util.concurrent.ConcurrentHashMap.newKeySet<String>()
    private val jobIds = java.util.concurrent.ConcurrentHashMap.newKeySet<String>()
    private val idPattern = Regex("[A-Za-z0-9_-]{1,64}")

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
        events = sink
    }

    override fun onCancel(arguments: Any?) {
        events = null
    }

    private fun send(jobId: String, percent: Double, eta: Long) {
        main.post {
            events?.success(mapOf("jobId" to jobId, "fraction" to percent.coerceIn(0.0, 1.0), "eta" to eta))
        }
    }

    private fun initialize() {
        YoutubeDL.init(context.applicationContext)
        FFmpeg.init(context.applicationContext)
    }

    fun health(): Map<String, Any> {
        initialize()
        return mapOf(
            "status" to "ok",
            "app" to "On-device downloader",
            "version" to (YoutubeDL.version(context) ?: "bundled"),
            "ffmpeg" to true,
            "yt_dlp" to true,
        )
    }

    fun info(url: String): Map<String, Any?> {
        requirePublicUrl(url)
        initialize()
        val request = YoutubeDLRequest(url).addOption("--no-playlist")
        val video = YoutubeDL.getInfo(request)
        return mapOf(
            "title" to (video.title ?: "Untitled"),
            "thumbnail" to (video.thumbnail ?: ""),
            "duration" to "${video.duration / 60}:${(video.duration % 60).toString().padStart(2, '0')}",
            "formats" to (video.formats ?: emptyList()).map { format ->
                mapOf(
                    "format_id" to (format.formatId ?: ""),
                    "format_note" to (format.formatNote ?: format.format ?: ""),
                    "ext" to (format.ext ?: ""),
                    "height" to format.height,
                    "filesize" to (format.fileSize.takeIf { it > 0 } ?: format.fileSizeApproximate),
                    "vcodec" to (format.vcodec ?: "none"),
                    "acodec" to (format.acodec ?: "none"),
                )
            },
        )
    }

    fun cancel(jobId: String): Boolean {
        if (!idPattern.matches(jobId) || !jobIds.contains(jobId)) return false
        cancelled.add(jobId)
        return YoutubeDL.destroyProcessById(jobId)
    }

    fun download(
        url: String,
        jobId: String,
        kind: String,
        formatId: String?,
        formatHasAudio: Boolean,
    ): Map<String, Any> {
        requirePublicUrl(url)
        require(idPattern.matches(jobId)) { "Invalid download ID" }
        require(jobIds.add(jobId)) { "Download is already running" }
        val dir = File(context.filesDir, "Saxify/Local/$jobId")
        try {
            if (!dir.exists() && !dir.mkdirs()) error("Cannot create download directory")
            initialize()
            if (cancelled.contains(jobId)) error("Download cancelled")
            val request = YoutubeDLRequest(url)
                .addOption("--no-playlist")
                .addOption("--newline")
                .addOption("--no-part")
                .addOption("-o", File(dir, "media.%(ext)s").absolutePath)

            // IDs originate in getInfo(), not from a shell. Only alphanumeric
            // yt-dlp format IDs may be used; never accept arbitrary options.
            val selected = formatId?.takeIf { it.matches(Regex("[A-Za-z0-9_-]{1,32}")) }
            when (kind) {
                "audio" -> request
                    .addOption("-f", selected ?: "bestaudio/best")
                    .addOption("--extract-audio")
                    .addOption("--audio-format", "mp3")
                    .addOption("--audio-quality", "0")
                "video_only" -> request.addOption("-f", selected ?: "bestvideo[ext=mp4]/bestvideo")
                "video" -> request
                    .addOption("-f", if (selected == null) {
                        "bestvideo[ext=mp4]+bestaudio[ext=m4a]/bestvideo+bestaudio/best[ext=mp4]/best"
                    } else {
                        if (formatHasAudio) selected else "$selected+bestaudio/$selected"
                    })
                    .addOption("--merge-output-format", "mp4/mkv")
                else -> throw IllegalArgumentException("Unknown download type")
            }

            var last = 0.0
            val percentage = Regex("\\[download]\\s+([0-9.]+)%")
            YoutubeDL.execute(request, jobId) { progress, eta, line ->
                // yt-dlp reports 100% for EACH stream, before merging. Keep
                // progress monotonic and reserve 100% for a verified final file.
                val value = progress.takeIf { it >= 0f }?.toDouble()
                    ?: percentage.find(line)?.groupValues?.get(1)?.toDoubleOrNull()
                if (value != null && !cancelled.contains(jobId)) {
                    last = max(last, (value / 100.0).coerceAtMost(0.96))
                    send(jobId, last, eta)
                }
            }
            if (cancelled.contains(jobId)) error("Download cancelled")
            val file = dir.listFiles()?.filter { it.isFile && !it.name.endsWith(".part") }
                ?.maxByOrNull { it.length() }
                ?: error("yt-dlp did not produce a file")
            if (file.length() < 1024) error("Downloaded file is empty")
            return mapOf("path" to file.absolutePath, "extension" to file.extension.lowercase(), "size" to file.length())
        } catch (e: Exception) {
            dir.deleteRecursively()
            if (cancelled.contains(jobId)) throw IllegalStateException("Download cancelled", e)
            throw e
        } finally {
            cancelled.remove(jobId)
            jobIds.remove(jobId)
        }
    }

    private fun requirePublicUrl(raw: String) {
        val uri = android.net.Uri.parse(raw)
        require(uri.scheme == "https" || uri.scheme == "http") { "Only public HTTP(S) links are supported" }
        require(!uri.host.isNullOrBlank()) { "Invalid link" }
    }
}
