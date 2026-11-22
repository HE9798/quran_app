package com.example.quran

import android.content.Context
import android.content.SharedPreferences

/** Companion mode: on/off, which companion, where it was left, and small notes for the app. */
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

    /** Speech bubbles on or off. */
    fun bubbles(context: Context) = prefs(context).getBoolean("bubbles", true)
    fun setBubbles(context: Context, on: Boolean) =
        prefs(context).edit().putBoolean("bubbles", on).apply()

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
