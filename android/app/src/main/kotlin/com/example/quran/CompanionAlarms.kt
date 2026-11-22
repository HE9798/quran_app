package com.example.quran

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings

/** Plans the speech bubbles for later (before a prayer, at prayer time, unfinished azkar). */
object CompanionAlarms {
    private const val KEY_IDS = "alarm_ids"

    private fun intentFor(context: Context, id: Int, text: String): PendingIntent {
        val intent = Intent(context, CompanionAlarmReceiver::class.java)
            .putExtra("text", text)
            .setAction("werd.companion.bubble.$id")
        return PendingIntent.getBroadcast(
            context, id, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
    }

    /** Replaces all planned bubbles with [events] (id, time in ms, text). */
    fun replaceAll(context: Context, events: List<Triple<Int, Long, String>>) {
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val prefs = CompanionStore.prefs(context)

        // remove the old ones
        (prefs.getString(KEY_IDS, "") ?: "").split(",").filter { it.isNotBlank() }.forEach {
            val id = it.toIntOrNull() ?: return@forEach
            manager.cancel(intentFor(context, id, ""))
        }

        val now = System.currentTimeMillis()
        val ids = mutableListOf<Int>()
        for ((id, at, text) in events) {
            if (at <= now) continue
            val pi = intentFor(context, id, text)
            val exact = Build.VERSION.SDK_INT < 31 || manager.canScheduleExactAlarms()
            if (exact) {
                manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
            } else {
                manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
            }
            ids.add(id)
        }
        prefs.edit().putString(KEY_IDS, ids.joinToString(",")).apply()
    }
}

/** Rings when a planned bubble is due: shows it above the companion. */
class CompanionAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val text = intent.getStringExtra("text") ?: return
        if (!CompanionStore.enabled(context)) return
        val running = CompanionOverlayService.instance
        if (running != null) {
            running.say(text, 25000)
        } else if (Settings.canDrawOverlays(context)) {
            // the companion service was stopped by the phone: bring it back with the bubble
            runCatching {
                val start = Intent(context, CompanionOverlayService::class.java)
                    .setAction(CompanionOverlayService.ACTION_SAY)
                    .putExtra("text", text)
                if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(start)
                else context.startService(start)
            }
        }
    }
}
