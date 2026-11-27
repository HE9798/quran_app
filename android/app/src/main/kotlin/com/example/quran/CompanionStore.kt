package com.example.quran

import android.content.Context
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import java.io.File

/** Companion mode: on/off, which companion, where it was left, and small notes for the app. */
object CompanionStore {
    private const val PREFS = "werd_companion"

    // ---- the pictures: the app (Flutter) is the only place that holds them. It
    // copies them here at start-up, and the floating companion reads them from here.
    private fun imageDir(context: Context) = File(context.filesDir, "companion")

    /** name = "sheikh_body", "sheikh_head", "sister_body", "sister_head" ... */
    fun imageFile(context: Context, name: String) = File(imageDir(context), "$name.png")

    /** Saves the pictures the app sends. A picture that did not change is not rewritten. True = something changed. */
    fun saveImages(context: Context, images: Map<String, ByteArray>): Boolean {
        val dir = imageDir(context)
        dir.mkdirs()
        var changed = false
        for ((name, bytes) in images) {
            val file = File(dir, "$name.png")
            val same = file.exists() && file.length() == bytes.size.toLong() &&
                runCatching { file.readBytes().contentEquals(bytes) }.getOrDefault(false)
            if (!same) {
                file.writeBytes(bytes)
                changed = true
            }
        }
        return changed
    }

    /**
     * A picture of the companion, from the copies the app made. An old copy in
     * the Android res folder is used only if that is missing.
     */
    fun loadPicture(context: Context, name: String, opts: BitmapFactory.Options): Bitmap? {
        val file = imageFile(context, name)
        if (file.exists()) {
            val bitmap = BitmapFactory.decodeFile(file.absolutePath, opts)
            if (bitmap != null) return bitmap
        }
        val id = context.resources.getIdentifier("companion_$name", "drawable", context.packageName)
        return if (id != 0) BitmapFactory.decodeResource(context.resources, id, opts) else null
    }

    fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    /** Companion mode is on: reminders (bubbles, lock screen) and coins. */
    fun enabled(context: Context) = prefs(context).getBoolean("enabled", false)
    fun setEnabled(context: Context, on: Boolean) =
        prefs(context).edit().putBoolean("enabled", on).apply()

    /**
     * The character was put away on the X with "keep reminders": it is not on
     * the screen, but its reminders still come (full screen on the lock
     * screen, a notification otherwise).
     */
    fun hidden(context: Context) = prefs(context).getBoolean("hidden", false)
    fun setHidden(context: Context, on: Boolean) =
        prefs(context).edit().putBoolean("hidden", on).apply()

    /** "sheikh" or "sister" */
    fun type(context: Context): String = prefs(context).getString("type", "sheikh") ?: "sheikh"
    fun setType(context: Context, type: String) =
        prefs(context).edit().putString("type", type).apply()

    /** Speech bubbles on or off. */
    fun bubbles(context: Context) = prefs(context).getBoolean("bubbles", true)
    fun setBubbles(context: Context, on: Boolean) =
        prefs(context).edit().putBoolean("bubbles", on).apply()

    /** Show the companion full screen over the lock screen when a bubble is due. */
    fun lockScreen(context: Context) = prefs(context).getBoolean("lock_screen", true)
    fun setLockScreen(context: Context, on: Boolean) =
        prefs(context).edit().putBoolean("lock_screen", on).apply()

    // ---- coins earned by the floating Tasbeeh button while the app was closed.
    // The app collects them (claimPending) and adds them to the wallet.
    fun addPending(context: Context, coins: Int) {
        val p = prefs(context)
        p.edit().putInt("pending_tasbeeh", p.getInt("pending_tasbeeh", 0) + coins).apply()
    }

    fun claimPending(context: Context): Int {
        val p = prefs(context)
        val n = p.getInt("pending_tasbeeh", 0)
        if (n != 0) p.edit().putInt("pending_tasbeeh", 0).apply()
        return n
    }

    // ---- phrases the app sends in the user's language (for bubbles made here)
    fun setString(context: Context, key: String, value: String) =
        prefs(context).edit().putString("str_$key", value).apply()

    fun string(context: Context, key: String, fallback: String): String =
        prefs(context).getString("str_$key", fallback) ?: fallback
}
