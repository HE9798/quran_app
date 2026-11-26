package com.example.quran

import android.app.Activity
import android.app.KeyguardManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.util.TypedValue
import android.view.Gravity
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView

/**
 * The companion on the lock screen. Android never shows "display over other
 * apps" windows on the lock screen, so when a bubble is due while the phone is
 * locked (or the screen is off) a full-screen notification opens
 * [CompanionLockActivity] on top of the lock screen instead.
 *
 * Android 14+ only lets alarm / calling apps use full-screen notifications by
 * default; other apps need the user to allow it ([allowed]). Without it the
 * bubble still shows as a normal notification on the lock screen.
 */
object CompanionLockScreen {
    private const val CHANNEL = "companion_lock"
    private const val NOTIFICATION_ID = 4250

    /** Locked, or the screen is off: the floating companion can't be seen. */
    fun phoneLocked(context: Context): Boolean {
        val keyguard = context.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        val power = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        return keyguard.isKeyguardLocked || !power.isInteractive
    }

    /** Full-screen notifications allowed for this app (always true before Android 14). */
    fun allowed(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < 34) return true
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return manager.canUseFullScreenIntent()
    }

    fun show(context: Context, text: String) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) {
            // high importance is required for a full-screen notification
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL, "Companion on the lock screen", NotificationManager.IMPORTANCE_HIGH)
                    .apply { setSound(null, null) }
            )
        }
        val open = PendingIntent.getActivity(
            context, NOTIFICATION_ID,
            Intent(context, CompanionLockActivity::class.java)
                .putExtra("text", text)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_USER_ACTION),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
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
            .setFullScreenIntent(open, true)
            .setContentIntent(open)
            .setAutoCancel(true)
            .apply { if (Build.VERSION.SDK_INT >= 26) setTimeoutAfter(10 * 60 * 1000L) }
            .build()
        manager.notify(NOTIFICATION_ID, notification)
    }

    fun cancel(context: Context) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.cancel(NOTIFICATION_ID)
    }
}

/**
 * Full screen on top of the lock screen: the companion (head bobbing) with its
 * speech bubble, and two buttons. Closes by itself after a while.
 */
class CompanionLockActivity : Activity() {

    private val handler = Handler(Looper.getMainLooper())
    private var bubble: BubbleView? = null
    private var companion: CompanionView? = null
    private val bob = object : Runnable {
        override fun run() {
            companion?.toggleBob()
            handler.postDelayed(this, 550)
        }
    }
    private val autoClose = Runnable { finish() }

    private fun dp(value: Float) =
        TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, value, resources.displayMetrics).toInt()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= 27) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
        // see-through: the companion hovers over the lock screen wallpaper
        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_SHOW_WALLPAPER
        )
        setContentView(buildLayout())
        showText(intent)
        handler.postDelayed(bob, 550)
        handler.postDelayed(autoClose, 30_000)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        showText(intent)
        handler.removeCallbacks(autoClose)
        handler.postDelayed(autoClose, 30_000)
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        CompanionLockScreen.cancel(this)
        super.onDestroy()
    }

    private fun showText(intent: Intent?) {
        val text = intent?.getStringExtra("text") ?: return
        bubble?.setContent(text)
    }

    private fun buildLayout(): ViewGroup {
        val root = FrameLayout(this) // transparent

        // the companion with its bubble and the buttons right under it, in the middle
        val middle = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
        }
        bubble = BubbleView(this) {}.also {
            middle.addView(it, LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { bottomMargin = -it.edgePad + dp(4f) })
        }
        val opts = BitmapFactory.Options().apply { inScaled = false }
        val type = CompanionStore.type(this)
        val body = CompanionStore.loadPicture(this, "${type}_body", opts)
        if (body != null) {
            val head = CompanionStore.loadPicture(this, "${type}_head", opts)
            val h = dp(220f)
            val w = (body.width * h.toFloat() / body.height).toInt()
            companion = CompanionView(this, body, head, w, h, dp(5f)).also {
                middle.addView(it, LinearLayout.LayoutParams(w, h + dp(5f)))
            }
        }
        // buttons right under the companion
        val buttons = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
        }
        buttons.addView(
            button(CompanionStore.string(this, "lock_dismiss", "Dismiss"), filled = false) { finish() },
            LinearLayout.LayoutParams(dp(140f), dp(48f)).apply { marginEnd = dp(12f) }
        )
        buttons.addView(
            button(CompanionStore.string(this, "lock_open", "Open app"), filled = true) { openApp() },
            LinearLayout.LayoutParams(dp(140f), dp(48f))
        )
        middle.addView(buttons, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply { topMargin = dp(20f) })

        // full width: a short bubble must not make the column narrower than the companion
        root.addView(middle, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.WRAP_CONTENT, Gravity.CENTER
        ))
        return root
    }

    private fun button(label: String, filled: Boolean, onTap: () -> Unit) = TextView(this).apply {
        text = label
        gravity = Gravity.CENTER
        textSize = 16f
        typeface = Typeface.DEFAULT_BOLD
        setTextColor(if (filled) Color.parseColor("#0E4F47") else Color.parseColor("#F7EBD4"))
        background = GradientDrawable().apply {
            cornerRadius = dp(26f).toFloat()
            if (filled) setColor(Color.parseColor("#F7EBD4"))
            else {
                setColor(Color.parseColor("#660A2E2A")) // readable on any wallpaper
                setStroke(dp(2f), Color.parseColor("#F7EBD4"))
            }
        }
        setOnClickListener { onTap() }
    }

    /** Asks to unlock (PIN / fingerprint), then opens the app. */
    private fun openApp() {
        val launch = packageManager.getLaunchIntentForPackage(packageName) ?: return finish()
        val keyguard = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        if (Build.VERSION.SDK_INT >= 26 && keyguard.isKeyguardLocked) {
            keyguard.requestDismissKeyguard(this, object : KeyguardManager.KeyguardDismissCallback() {
                override fun onDismissSucceeded() {
                    startActivity(launch)
                    finish()
                }
            })
        } else {
            startActivity(launch)
            finish()
        }
    }
}
