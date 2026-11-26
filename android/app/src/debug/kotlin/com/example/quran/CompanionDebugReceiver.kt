package com.example.quran

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * DEBUG BUILDS ONLY (lives in src/debug): fires a companion bubble from the
 * computer, exactly as a planned bubble alarm would, to test it on the lock
 * screen without waiting for a prayer time:
 *
 *   adb shell am broadcast -n com.example.quran/.CompanionDebugReceiver --es text "Hello"
 */
class CompanionDebugReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val text = intent.getStringExtra("text") ?: "Assalamu alaykum"
        CompanionAlarmReceiver().onReceive(context, Intent().putExtra("text", text))
    }
}
