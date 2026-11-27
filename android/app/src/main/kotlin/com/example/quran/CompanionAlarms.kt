package com.example.quran

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import org.json.JSONArray
import org.json.JSONObject

/**
 * Plans the speech bubbles for later (before a prayer, at prayer time,
 * unfinished azkar). The list is also saved, because Android forgets planned
 * alarms when the phone restarts or the app is updated:
 * [CompanionBootReceiver] plans them again from the saved list, so they keep
 * coming even if the app is not opened.
 */
object CompanionAlarms {
    private const val KEY_IDS = "alarm_ids"
    private const val KEY_EVENTS = "alarm_events"

    private fun intentFor(context: Context, id: Int, text: String): PendingIntent {
        val intent = Intent(context, CompanionAlarmReceiver::class.java)
            .putExtra("text", text)
            .setAction("werd.companion.bubble.$id")
        return PendingIntent.getBroadcast(
            context, id, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
    }

    /** Replaces all planned bubbles with [events] (id, time in ms, text) and saves them. */
    fun replaceAll(context: Context, events: List<Triple<Int, Long, String>>) {
        val saved = JSONArray()
        for ((id, at, text) in events) {
            saved.put(JSONObject().put("id", id).put("at", at).put("text", text))
        }
        CompanionStore.prefs(context).edit().putString(KEY_EVENTS, saved.toString()).apply()
        schedule(context, events)
    }

    /** After a restart or an update: plans the saved bubbles again (past ones are skipped). */
    fun restore(context: Context) {
        val raw = CompanionStore.prefs(context).getString(KEY_EVENTS, null) ?: return
        val events = runCatching {
            val list = JSONArray(raw)
            (0 until list.length()).map {
                val e = list.getJSONObject(it)
                Triple(e.getInt("id"), e.getLong("at"), e.getString("text"))
            }
        }.getOrNull() ?: return
        schedule(context, events)
    }

    private fun schedule(context: Context, events: List<Triple<Int, Long, String>>) {
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val prefs = CompanionStore.prefs(context)

        // remove the old ones
        (prefs.getString(KEY_IDS, "") ?: "").split(",").filter { it.isNotBlank() }.forEach {
            val id = it.toIntOrNull() ?: return@forEach
            manager.cancel(intentFor(context, id, ""))
        }

        val now = System.currentTimeMillis()
        val exact = Build.VERSION.SDK_INT < 31 || manager.canScheduleExactAlarms()
        val ids = mutableListOf<Int>()
        for ((id, at, text) in events) {
            if (at <= now) continue
            val pi = intentFor(context, id, text)
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

/** The phone restarted or the app was updated: plan the saved bubbles again. */
class CompanionBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (CompanionStore.enabled(context)) CompanionAlarms.restore(context)
    }
}

/**
 * Rings when a planned bubble is due.
 *  - phone locked: the companion full screen over the lock screen
 *  - character on screen: a bubble above it
 *  - character put away, or it can't be started now: a normal notification,
 *    so the reminder is never lost
 */
class CompanionAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val text = intent.getStringExtra("text") ?: return
        if (!CompanionStore.enabled(context) || !CompanionStore.bubbles(context)) return

        // the floating companion can't be seen on the lock screen: show it full screen there
        if (CompanionLockScreen.phoneLocked(context)) {
            if (CompanionStore.lockScreen(context)) CompanionLockScreen.show(context, text)
            else CompanionReminder.show(context, text)
            return
        }
        if (CompanionStore.hidden(context) || !Settings.canDrawOverlays(context)) {
            CompanionReminder.show(context, text)
            return
        }
        val running = CompanionOverlayService.instance
        if (running != null) {
            running.say(text, 8000)
            return
        }
        // the companion service was stopped by the phone: bring it back with the bubble.
        // Android may refuse to start it from the background (e.g. without exact
        // alarms): then the reminder comes as a notification instead.
        val started = runCatching {
            val start = Intent(context, CompanionOverlayService::class.java)
                .setAction(CompanionOverlayService.ACTION_SAY)
                .putExtra("text", text)
            if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(start)
            else context.startService(start)
        }.isSuccess
        if (!started) CompanionReminder.show(context, text)
    }
}

/** A reminder as a normal notification (heads-up), from the companion. */
object CompanionReminder {
    private const val CHANNEL = "companion_reminder"
    private const val NOTIFICATION_ID = 4251

    fun show(context: Context, text: String) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL,
                    CompanionStore.string(context, "reminder_channel", "Companion reminders"),
                    NotificationManager.IMPORTANCE_HIGH
                ).apply { setSound(null, null) } // the adhan has its own sound
            )
        }
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val open = PendingIntent.getActivity(
            context, NOTIFICATION_ID, launch, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val builder = if (Build.VERSION.SDK_INT >= 26)
            Notification.Builder(context, CHANNEL) else Notification.Builder(context)
        @Suppress("DEPRECATION")
        val notification = builder
            .setSmallIcon(context.applicationInfo.icon)
            .setContentTitle(CompanionStore.string(context, "lock_title", "Your companion"))
            .setContentText(text)
            .setCategory(Notification.CATEGORY_REMINDER)
            .setPriority(Notification.PRIORITY_HIGH)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setContentIntent(open)
            .setAutoCancel(true)
            .apply { if (Build.VERSION.SDK_INT >= 26) setTimeoutAfter(15 * 60 * 1000L) }
            .build()
        manager.notify(NOTIFICATION_ID, notification)
    }
}
