package com.saxify.app

import android.content.Context
import java.io.File

/**
 * Part 2 — freeze-proof crash counter (native half).
 *
 * Counts uncaught native crashes in a plain file inside the app's private
 * files dir (context.filesDir). The Dart side (BootGuard) reads the same
 * file through path_provider — a shared text file means zero platform
 * channel surface and nothing that can break the build on Flutter updates.
 *
 * Three consecutive crashes (the file value reaching 3) make the next
 * launch boot in safe mode; Dart clears the file after a clean boot.
 */
object CrashGuard {
    private const val FILE_NAME = "saxify_crash_count"

    fun install(context: Context) {
        val dir = context.filesDir
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            try {
                val file = File(dir, FILE_NAME)
                val current = file.takeIf { it.exists() }
                    ?.readText()?.trim()?.toIntOrNull() ?: 0
                file.writeText((current + 1).toString())
            } catch (_: Exception) {
                // counting must never mask the original crash
            }
            // Hand back to the previous handler so the crash still happens
            // (and shows in the crash reports) — we only *count* it.
            previous?.uncaughtException(thread, throwable)
        }
    }

    /** Current crash count (0 when the file is absent or unreadable). */
    fun count(context: Context): Int {
        return try {
            val file = File(context.filesDir, FILE_NAME)
            file.takeIf { it.exists() }?.readText()?.trim()?.toIntOrNull() ?: 0
        } catch (_: Exception) {
            0
        }
    }

    /** Clears the count (called after a successful boot, from Dart). */
    fun reset(context: Context) {
        try {
            val file = File(context.filesDir, FILE_NAME)
            if (file.exists()) file.delete()
        } catch (_: Exception) {
        }
    }
}
