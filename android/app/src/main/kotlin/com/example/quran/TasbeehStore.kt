package com.example.quran

import android.content.Context
import android.content.SharedPreferences

/** The Tasbeeh count: shared by the floating button and the app's settings. */
object TasbeehStore {
    private const val PREFS = "werd_tasbeeh_widget"
    private const val KEY_COUNT = "count"
    private const val KEY_COMBO = "combo"
    private const val KEY_OVERLAY = "overlay_enabled"
    private const val KEY_TARGET = "target"

    fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun count(context: Context): Int = prefs(context).getInt(KEY_COUNT, 0)
    fun combo(context: Context): Int = prefs(context).getInt(KEY_COMBO, 0)

    /** The number the slider fills at (10, 33, 100, 1000 ...). */
    fun target(context: Context): Int = prefs(context).getInt(KEY_TARGET, 100).coerceAtLeast(1)

    fun setTarget(context: Context, target: Int) {
        val p = prefs(context)
        val t = target.coerceIn(1, 100000)
        val edit = p.edit().putInt(KEY_TARGET, t)
        if (p.getInt(KEY_COUNT, 0) >= t) edit.putInt(KEY_COUNT, 0)
        edit.apply()
    }

    /** One more tasbeeh. When the slider is full the combo goes up and the count restarts. */
    fun increment(context: Context) {
        val p = prefs(context)
        var count = p.getInt(KEY_COUNT, 0) + 1
        var combo = p.getInt(KEY_COMBO, 0)
        if (count >= target(context)) {
            count = 0
            combo += 1
        }
        p.edit().putInt(KEY_COUNT, count).putInt(KEY_COMBO, combo).apply()
    }

    fun reset(context: Context) {
        prefs(context).edit().putInt(KEY_COUNT, 0).putInt(KEY_COMBO, 0).apply()
    }

    fun overlayEnabled(context: Context): Boolean = prefs(context).getBoolean(KEY_OVERLAY, false)

    fun setOverlayEnabled(context: Context, enabled: Boolean) {
        prefs(context).edit().putBoolean(KEY_OVERLAY, enabled).apply()
    }

    fun arabicDigits(context: Context): Boolean {
        // the app's own language setting (saved by Flutter)
        val flutter = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        return flutter.getString("flutter.set_lang_v1", "en") == "ar"
    }

    fun digits(text: String, arabic: Boolean): String {
        if (!arabic) return text
        val sb = StringBuilder()
        for (c in text) sb.append(if (c in '0'..'9') ('٠' + (c - '0')) else c)
        return sb.toString()
    }
}
