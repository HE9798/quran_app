package com.example.quran

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.animation.ValueAnimator
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.ServiceInfo
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.util.TypedValue
import android.view.Gravity
import android.view.HapticFeedbackConstants
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import kotlin.math.abs
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min

/**
 * The Tasbeeh button that floats on top of other apps.
 * Tap = +1. Drag to move it. While dragging, a fire appears at the bottom of
 * the screen: let go over it to close the button (turn it on again from the
 * app's settings). The combo bar "(x1)" sits ABOVE the button.
 */
class TasbeehOverlayService : Service() {

    private lateinit var windowManager: WindowManager
    private var root: LinearLayout? = null      // bar (optional) + button
    private var countView: TextView? = null
    private var comboView: TextView? = null
    private var trash: FrameLayout? = null      // the fire's window
    private var glowBackground: GradientDrawable? = null // the orange circle
    private var fireIcon: View? = null                   // the flame
    private val handler = Handler(Looper.getMainLooper())
    private var flip: Runnable? = null
    private var pulse: ValueAnimator? = null
    private lateinit var params: WindowManager.LayoutParams
    private var showingCombo = false

    private val listener = SharedPreferences.OnSharedPreferenceChangeListener { _, _ -> refresh() }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startAsForeground()
        if (!Settings.canDrawOverlays(this)) {
            stopSelf()
            return START_NOT_STICKY
        }
        if (root == null) createOverlay()
        return START_STICKY
    }

    override fun onDestroy() {
        stopEffects()
        TasbeehStore.prefs(this).unregisterOnSharedPreferenceChangeListener(listener)
        root?.let { runCatching { windowManager.removeView(it) } }
        trash?.let { runCatching { windowManager.removeView(it) } }
        root = null
        trash = null
        super.onDestroy()
    }

    // ---------------------------------------------------------- notification
    private fun startAsForeground() {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(
                NotificationChannel("tasbeeh_overlay", "Tasbeeh button", NotificationManager.IMPORTANCE_MIN)
            )
        }
        val open = PendingIntent.getActivity(
            this, 0, packageManager.getLaunchIntentForPackage(packageName),
            PendingIntent.FLAG_IMMUTABLE
        )
        val builder = if (Build.VERSION.SDK_INT >= 26)
            Notification.Builder(this, "tasbeeh_overlay") else Notification.Builder(this)
        val notification = builder
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle("Tasbeeh button is on")
            .setContentText("Drag it to the fire to close it")
            .setContentIntent(open)
            .setOngoing(true)
            .build()
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(4242, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(4242, notification)
        }
    }

    // --------------------------------------------------------------- overlay
    private fun dp(value: Float) =
        TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, value, resources.displayMetrics).toInt()

    private val button get() = dp(72f)          // the green square
    private val barHeight get() = dp(36f)       // half of the button
    private val gap get() = dp(4f)

    private fun rounded(color: String, radius: Float) = GradientDrawable().apply {
        setColor(Color.parseColor(color))
        cornerRadius = radius
    }

    private fun createOverlay() {
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager

        // ---- the fire (created first so the button is drawn above it).
        // A reddish-orange circle whose edge fades out, so there is no border.
        // The window is bigger than the circle so it can grow by 25%.
        val glow = FrameLayout(this).apply {
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                gradientType = GradientDrawable.RADIAL_GRADIENT
                gradientRadius = dp(56f).toFloat()
                setGradientCenter(0.5f, 0.5f)
                colors = intArrayOf(
                    Color.parseColor("#FFFB3E04"),
                    Color.parseColor("#FFFB3E04"),
                    Color.parseColor("#00FB3E04")
                )
            }
        }
        // Your own icon: put it in res/drawable/fire_icon.png. Without it the
        // fire emoji is used.
        val iconId = resources.getIdentifier("fire_icon", "drawable", packageName)
        val icon: View = if (iconId != 0) {
            ImageView(this).apply {
                setImageResource(iconId)
                scaleType = ImageView.ScaleType.FIT_CENTER
            }
        } else {
            TextView(this).apply {
                text = "\uD83D\uDD25" // fire
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 34f)
                gravity = Gravity.CENTER
            }
        }
        glow.addView(icon, FrameLayout.LayoutParams(dp(48f), dp(48f), Gravity.CENTER))
        val bin = FrameLayout(this).apply {
            addView(glow, FrameLayout.LayoutParams(dp(112f), dp(112f), Gravity.CENTER))
            visibility = View.GONE
        }
        glowBackground = glow.background as GradientDrawable
        fireIcon = icon
        val binParams = WindowManager.LayoutParams(
            dp(140f), dp(140f),
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
            y = dp(26f)
        }
        windowManager.addView(bin, binParams)
        trash = bin

        // ---- the combo bar (above) and the button
        val bar = TextView(this).apply {
            gravity = Gravity.CENTER
            setTextColor(Color.parseColor("#12685E"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 20f)
            typeface = Typeface.DEFAULT_BOLD
            includeFontPadding = false
            background = rounded("#F7EBD4", dp(14f).toFloat())
            elevation = dp(6f).toFloat()
            visibility = View.GONE
        }
        val count = TextView(this).apply {
            gravity = Gravity.CENTER
            setTextColor(Color.parseColor("#F7EBD4"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 30f)
            typeface = Typeface.DEFAULT_BOLD
            includeFontPadding = false
            background = rounded("#12685E", dp(20f).toFloat())
            elevation = dp(6f).toFloat()
        }
        val layout = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        layout.addView(bar, LinearLayout.LayoutParams(button, barHeight).apply { bottomMargin = gap })
        layout.addView(count, LinearLayout.LayoutParams(button, button))

        val metrics = resources.displayMetrics
        val saved = TasbeehStore.prefs(this)
        params = WindowManager.LayoutParams(
            button, button,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = saved.getInt("overlay_x", metrics.widthPixels - button - dp(16f))
            y = saved.getInt("overlay_y", metrics.heightPixels / 3)
        }

        layout.setOnTouchListener(touchListener(layout))
        windowManager.addView(layout, params)
        root = layout
        countView = count
        comboView = bar
        saved.registerOnSharedPreferenceChangeListener(listener)
        refresh()
    }

    /** Updates the number and shows/hides the bar. The button itself never jumps. */
    private fun refresh() {
        val r = root ?: return
        val arabic = TasbeehStore.arabicDigits(this)
        val count = TasbeehStore.count(this)
        val combo = TasbeehStore.combo(this)
        countView?.text = TasbeehStore.digits(count.toString().padStart(3, '0'), arabic)

        val wantBar = combo > 0
        if (wantBar) comboView?.text = TasbeehStore.digits("(x$combo)", arabic)
        if (wantBar != showingCombo) {
            showingCombo = wantBar
            val extra = barHeight + gap
            comboView?.visibility = if (wantBar) View.VISIBLE else View.GONE
            params.height = if (wantBar) button + extra else button
            // the bar grows upwards: move the window so the button stays where it is
            params.y += if (wantBar) -extra else extra
            runCatching { windowManager.updateViewLayout(r, params) }
        }
    }

    // ------------------------------------------------------------- the fire
    // Static (button not over it): the flame flips left/right, like it is
    // flickering. Hovering (button over it): the orange glow pulses.
    // Opacity can not go above 100%, so the glow pulses between 33% and 100%
    // and rests at 66%: the same 1 : 2 : 3 steps as 50% / 100% / 150%.
    private val restAlpha = 168   // 66%
    private val dimAlpha = 84     // 33%
    private val fullAlpha = 255   // 100%

    private fun setHover(on: Boolean) {
        pulse?.cancel()
        pulse = null
        if (on) {
            if (flip == null) startFlip() // keep flipping while hovering
            pulse = ValueAnimator.ofInt(dimAlpha, fullAlpha).apply {
                duration = 450
                repeatMode = ValueAnimator.REVERSE
                repeatCount = ValueAnimator.INFINITE
                addUpdateListener { glowBackground?.alpha = it.animatedValue as Int }
                start()
            }
        } else {
            glowBackground?.alpha = restAlpha
            if (flip == null) startFlip()
        }
    }

    private fun startFlip() {
        stopFlip()
        val r = object : Runnable {
            override fun run() {
                fireIcon?.scaleX = -(fireIcon?.scaleX ?: 1f)
                handler.postDelayed(this, 350)
            }
        }
        flip = r
        handler.postDelayed(r, 350)
    }

    private fun stopFlip() {
        flip?.let { handler.removeCallbacks(it) }
        flip = null
        fireIcon?.scaleX = 1f
    }

    private fun stopEffects() {
        pulse?.cancel()
        pulse = null
        stopFlip()
        glowBackground?.alpha = restAlpha
    }

    // ------------------------------------------------------------- touching
    /** Tap = +1, drag = move, let go over the fire = close. */
    private fun touchListener(view: LinearLayout): View.OnTouchListener {
        val slop = ViewConfiguration.get(this).scaledTouchSlop
        var downX = 0f
        var downY = 0f
        var startX = 0
        var startY = 0
        var dragging = false
        var overBin = false

        fun center(v: View): Pair<Float, Float> {
            val loc = IntArray(2)
            v.getLocationOnScreen(loc)
            return Pair(loc[0] + v.width / 2f, loc[1] + v.height / 2f)
        }

        /** The centre of the green button (not the bar). */
        fun buttonCenter(): Pair<Float, Float> {
            val loc = IntArray(2)
            countView?.getLocationOnScreen(loc)
            return Pair(loc[0] + button / 2f, loc[1] + button / 2f)
        }

        fun checkBin(): Boolean {
            val b = trash ?: return false
            val (bx, by) = center(b)
            val (cx, cy) = buttonCenter()
            return hypot(cx - bx, cy - by) < dp(64f)
        }

        return View.OnTouchListener { _, e ->
            when (e.action) {
                MotionEvent.ACTION_DOWN -> {
                    downX = e.rawX; downY = e.rawY
                    startX = params.x; startY = params.y
                    dragging = false
                    overBin = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = e.rawX - downX
                    val dy = e.rawY - downY
                    if (!dragging && (abs(dx) > slop || abs(dy) > slop)) {
                        dragging = true
                        trash?.visibility = View.VISIBLE
                        setHover(false) // static: the flame flips
                    }
                    if (dragging) {
                        val m = resources.displayMetrics
                        // keep the whole button on the screen
                        params.x = (startX + dx.toInt()).coerceIn(0, max(0, m.widthPixels - params.width))
                        params.y = (startY + dy.toInt()).coerceIn(0, max(0, m.heightPixels - params.height))
                        windowManager.updateViewLayout(view, params)

                        val now = checkBin()
                        if (now != overBin) {
                            overBin = now
                            setHover(now)
                            if (now) view.performHapticFeedback(HapticFeedbackConstants.LONG_PRESS)
                        }
                    }
                    true
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    trash?.visibility = View.GONE
                    stopEffects()
                    if (!dragging) {
                        if (e.action == MotionEvent.ACTION_UP) {
                            TasbeehStore.increment(this)
                        }
                    } else if (overBin) {
                        // closed with the fire; turn it on again from the app's settings
                        TasbeehStore.setOverlayEnabled(this, false)
                        stopSelf()
                    } else {
                        // remember the button's place (not counting the bar)
                        val barExtra = if (showingCombo) barHeight + gap else 0
                        TasbeehStore.prefs(this).edit()
                            .putInt("overlay_x", params.x)
                            .putInt("overlay_y", params.y + barExtra)
                            .apply()
                    }
                    true
                }
                else -> false
            }
        }
    }
}
