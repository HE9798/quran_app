package com.example.quran

import android.content.Context
import android.content.SharedPreferences

/** Companion mode: on/off, which companion, and where it was left on the screen. */
object CompanionStore {
    private const val PREFS = "werd_companion"

    fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun enabled(context: Context) = prefs(context).getBoolean("enabled", false)
    fun setEnabled(context: Context, on: Boolean) =
        prefs(context).edit().putBoolean("enabled", on).apply()

    /** "sheikh" or "sister" */
    fun type(context: Context): String = prefs(context).getString("type", "sheikh") ?: "sheikh"
    fun setType(context: Context, type: String) =
        prefs(context).edit().putString("type", type).apply()
}
