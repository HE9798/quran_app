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
import android.content.res.Configuration
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.LayerDrawable
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
    private var countView: View? = null          // the 3D button
    private var comboView: TextView? = null
    private var slider: SliderView? = null
    private var sliderLeft = true                // which side of the button the slider is on
    private var shownCombo = -1
    private var completing = false
    private var trash: FrameLayout? = null      // the fire's window
    private var glowBackground: GradientDrawable? = null // the orange circle
    private var fireIcon: View? = null                   // the flame
    private val handler = Handler(Looper.getMainLooper())
    private var flip: Runnable? = null
    private var pulse: ValueAnimator? = null
    private lateinit var params: WindowManager.LayoutParams

    private val listener = SharedPreferences.OnSharedPreferenceChangeListener { _, _ -> refresh() }
    // the app's own settings (theme): recolour when they change
    private val themeListener = SharedPreferences.OnSharedPreferenceChangeListener { _, _ -> applyTheme() }
    private fun flutterPrefs() = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

    override fun onBind(intent: Intent?): IBinder? = null

    // the phone switched between light and dark: matters when the app follows the phone
    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        applyTheme()
    }

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
        flutterPrefs().unregisterOnSharedPreferenceChangeListener(themeListener)
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

    private val button get() = dp(72f)          // the square button
    private val barHeight get() = dp(36f)       // half of the button
    private val gap get() = dp(4f)
    private val pad get() = dp(6f)              // room for the soft shadows
    private val sliderW get() = dp(26f)
    private val sideGap get() = dp(8f)
    private val extra get() = sliderW + sideGap
    private val bodyHeight get() = barHeight + gap + button

    /** Where the button sits inside the window, depending on the slider's side. */
    private fun offX(left: Boolean) = pad + (if (left) extra else 0)
    private val offY get() = pad + barHeight + gap

    private fun rounded(color: String, radius: Float) = GradientDrawable().apply {
        setColor(Color.parseColor(color))
        cornerRadius = radius
    }

    private fun gradient(from: String, to: String, radius: Float) = GradientDrawable(
        GradientDrawable.Orientation.TL_BR,
        intArrayOf(Color.parseColor(from), Color.parseColor(to))
    ).apply { cornerRadius = radius }

    /** Follows the app's theme: "follow the phone" or its own light/dark switch. */
    private fun isDark(): Boolean {
        val p = flutterPrefs()
        return if (p.getBoolean("flutter.set_follow_device_v1", true)) {
            (resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
                Configuration.UI_MODE_NIGHT_YES
        } else {
            p.getBoolean("flutter.set_dark_v1", false)
        }
    }

    /** Rounded square, edges slightly raised, middle slightly sunk. Kept subtle. */
    private fun sunkenButton(dark: Boolean): LayerDrawable {
        // dark theme: green button. light theme: cream button.
        val raised = if (dark) gradient("#1A7C71", "#0E4F47", dp(22f).toFloat())
                     else gradient("#FFFAEC", "#E0CFA8", dp(22f).toFloat())
        val dish = if (dark) gradient("#0F554C", "#167267", dp(16f).toFloat())
                   else gradient("#E8DABA", "#F8EFD9", dp(16f).toFloat())
        return LayerDrawable(arrayOf(raised, dish)).apply {
            val i = dp(7f)
            setLayerInset(1, i, i, i, i)
        }
    }

    /** Dark theme: green button, cream bar + slider. Light theme: the opposite. */
    private fun applyTheme() {
        val dark = isDark()
        comboView?.apply {
            background = rounded(if (dark) "#F7EBD4" else "#12685E", dp(14f).toFloat())
            setTextColor(Color.parseColor(if (dark) "#12685E" else "#F7EBD4"))
        }
        countView?.background = sunkenButton(dark)
        slider?.setDark(dark)
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

        // ---- the combo bar (above), the 3D button, and the slider beside them
        val bar = TextView(this).apply {
            gravity = Gravity.CENTER
            setTextColor(Color.parseColor("#12685E"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 20f)
            typeface = Typeface.DEFAULT_BOLD
            includeFontPadding = false
            background = rounded("#F7EBD4", dp(14f).toFloat())
            elevation = dp(5f).toFloat()
        }
        val face = View(this).apply {
            background = sunkenButton(true)
            elevation = dp(5f).toFloat()
        }
        val sl = SliderView(this)
        val column = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        column.addView(bar, LinearLayout.LayoutParams(button, barHeight).apply { bottomMargin = gap })
        column.addView(face, LinearLayout.LayoutParams(button, button))
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(pad, pad, pad, pad)
            clipToPadding = false
            clipChildren = false
        }
        layout.addView(column, LinearLayout.LayoutParams(button, bodyHeight))
        slider = sl
        root = layout
        countView = face
        comboView = bar

        val metrics = resources.displayMetrics
        val saved = TasbeehStore.prefs(this)
        // the saved place is the BUTTON's place
        val bx = saved.getInt("overlay_x", metrics.widthPixels - button - dp(16f))
        val by = saved.getInt("overlay_y", metrics.heightPixels / 3)
        sliderLeft = bx + button / 2 > metrics.widthPixels / 2   // on the right half: slider goes left
        placeSlider(sliderLeft)

        params = WindowManager.LayoutParams(
            pad * 2 + button + extra, pad * 2 + bodyHeight,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = bx - offX(sliderLeft)
            y = by - offY
        }

        layout.setOnTouchListener(touchListener(layout))
        windowManager.addView(layout, params)
        saved.registerOnSharedPreferenceChangeListener(listener)
        flutterPrefs().registerOnSharedPreferenceChangeListener(themeListener)
        applyTheme()
        refresh()
    }

    /** Puts the slider on the left or the right of the button. */
    private fun placeSlider(left: Boolean) {
        val r = root ?: return
        val sl = slider ?: return
        sliderLeft = left
        r.removeView(sl)
        val lp = LinearLayout.LayoutParams(sliderW, bodyHeight)
        if (left) lp.rightMargin = sideGap else lp.leftMargin = sideGap
        r.addView(sl, if (left) 0 else 1, lp)
    }

    private fun fraction(): Float {
        val target = max(1, TasbeehStore.target(this))
        return min(1f, TasbeehStore.count(this).toFloat() / target)
    }

    private fun setBar(combo: Int, pop: Boolean) {
        val arabic = TasbeehStore.arabicDigits(this)
        comboView?.text = TasbeehStore.digits("x$combo", arabic)
        shownCombo = combo
        if (pop) {
            comboView?.animate()?.cancel()
            comboView?.scaleX = 1f
            comboView?.scaleY = 1f
            comboView?.animate()?.scaleX(1.18f)?.scaleY(1.18f)?.setDuration(140)?.withEndAction {
                comboView?.animate()?.scaleX(1f)?.scaleY(1f)?.setDuration(140)?.start()
            }?.start()
        }
    }

    /**
     * Slider follows the count. When the chosen number is reached the slider
     * is full for a moment, the bar pops to the next "x", and the slider empties.
     */
    private fun refresh() {
        val sl = slider ?: return
        val combo = TasbeehStore.combo(this)
        if (shownCombo < 0) {            // first time
            setBar(combo, false)
            sl.setNow(fraction())
            return
        }
        if (combo > shownCombo) {        // the target was reached
            completing = true
            sl.animateTo(1f)
            handler.postDelayed({
                completing = false
                setBar(TasbeehStore.combo(this), true)
                sl.animateTo(fraction())
            }, 350)
            return
        }
        if (combo < shownCombo) setBar(combo, false) // reset from the app
        if (!completing) sl.animateTo(fraction())
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
    /** Tap the button = +1, drag anywhere = move, let go over the fire = close. */
    private fun touchListener(view: LinearLayout): View.OnTouchListener {
        val slop = ViewConfiguration.get(this).scaledTouchSlop
        var downX = 0f
        var downY = 0f
        var startX = 0
        var startY = 0
        var dragging = false
        var overBin = false
        var onButton = false

        fun center(v: View): Pair<Float, Float> {
            val loc = IntArray(2)
            v.getLocationOnScreen(loc)
            return Pair(loc[0] + v.width / 2f, loc[1] + v.height / 2f)
        }

        fun buttonCenter(): Pair<Float, Float> {
            val loc = IntArray(2)
            countView?.getLocationOnScreen(loc)
            return Pair(loc[0] + button / 2f, loc[1] + button / 2f)
        }

        fun touchedButton(x: Float, y: Float): Boolean {
            val v = countView ?: return false
            val loc = IntArray(2)
            v.getLocationOnScreen(loc)
            return x >= loc[0] && x <= loc[0] + v.width && y >= loc[1] && y <= loc[1] + v.height
        }

        fun checkBin(): Boolean {
            val b = trash ?: return false
            val (bx, by) = center(b)
            val (cx, cy) = buttonCenter()
            return hypot(cx - bx, cy - by) < dp(64f)
        }

        fun release() {
            countView?.animate()?.scaleX(1f)?.scaleY(1f)?.setDuration(90)?.start()
        }

        return View.OnTouchListener { _, e ->
            when (e.action) {
                MotionEvent.ACTION_DOWN -> {
                    downX = e.rawX; downY = e.rawY
                    startX = params.x; startY = params.y
                    dragging = false
                    overBin = false
                    onButton = touchedButton(e.rawX, e.rawY)
                    if (onButton) countView?.animate()?.scaleX(0.95f)?.scaleY(0.95f)?.setDuration(70)?.start()
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = e.rawX - downX
                    val dy = e.rawY - downY
                    if (!dragging && (abs(dx) > slop || abs(dy) > slop)) {
                        dragging = true
                        release()
                        trash?.visibility = View.VISIBLE
                        setHover(false)
                    }
                    if (dragging) {
                        val m = resources.displayMetrics
                        params.x = (startX + dx.toInt()).coerceIn(0, max(0, m.widthPixels - params.width))
                        params.y = (startY + dy.toInt()).coerceIn(0, max(0, m.heightPixels - params.height))

                        // button crossed the middle of the screen: flip the design,
                        // keeping the button exactly where it is
                        val cx = params.x + offX(sliderLeft) + button / 2
                        val wantLeft = cx > m.widthPixels / 2
                        if (wantLeft != sliderLeft) {
                            val shift = offX(sliderLeft) - offX(wantLeft)
                            params.x += shift
                            startX += shift
                            placeSlider(wantLeft)
                        }
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
                    release()
                    if (!dragging) {
                        if (e.action == MotionEvent.ACTION_UP && onButton) {
                            TasbeehStore.increment(this)
                        }
                    } else if (overBin) {
                        TasbeehStore.setOverlayEnabled(this, false)
                        stopSelf()
                    } else {
                        TasbeehStore.prefs(this).edit()
                            .putInt("overlay_x", params.x + offX(sliderLeft))
                            .putInt("overlay_y", params.y + offY)
                            .apply()
                    }
                    true
                }
                else -> false
            }
        }
    }
}

/** The vertical slider: a track, a filled part and a round knob that moves up. */
private class SliderView(context: Context) : View(context) {
    private var fraction = 0f
    private var animator: ValueAnimator? = null
    private val d = resources.displayMetrics.density
    private val track = Paint(Paint.ANTI_ALIAS_FLAG)
    private val channel = Paint(Paint.ANTI_ALIAS_FLAG)
    private val fill = Paint(Paint.ANTI_ALIAS_FLAG)
    private val knob = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        setShadowLayer(3f * d, 0f, 1.5f * d, Color.parseColor("#55000000"))
    }
    private val ring = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 2f * d
    }
    private val dot = Paint(Paint.ANTI_ALIAS_FLAG)
    private var trackA = 0
    private var trackB = 0

    init { setDark(true) }

    /** Dark theme: cream slider with a green fill. Light theme: green slider with a cream fill. */
    fun setDark(dark: Boolean) {
        val cream = Color.parseColor("#F7EBD4")
        val teal = Color.parseColor("#12685E")
        if (dark) {
            trackA = Color.parseColor("#D9CBA9"); trackB = Color.parseColor("#F6ECD6")
            channel.color = Color.parseColor("#CBBD9B")
            fill.color = teal; knob.color = cream; ring.color = teal; dot.color = teal
        } else {
            trackA = Color.parseColor("#0C4A43"); trackB = Color.parseColor("#1A7C71")
            channel.color = Color.parseColor("#0A3D37")
            fill.color = cream; knob.color = teal; ring.color = cream; dot.color = cream
        }
        invalidate()
    }
    private val rect = RectF()

    init { setLayerType(LAYER_TYPE_SOFTWARE, null) } // needed for the knob's shadow

    fun setNow(f: Float) {
        animator?.cancel()
        fraction = f.coerceIn(0f, 1f)
        invalidate()
    }

    fun animateTo(f: Float) {
        val to = f.coerceIn(0f, 1f)
        animator?.cancel()
        animator = ValueAnimator.ofFloat(fraction, to).apply {
            duration = 220
            addUpdateListener { fraction = it.animatedValue as Float; invalidate() }
            start()
        }
    }

    override fun onDraw(canvas: Canvas) {
        val w = width.toFloat()
        val h = height.toFloat()
        track.shader = LinearGradient(0f, 0f, w, 0f,
            trackA, trackB, Shader.TileMode.CLAMP)
        rect.set(0f, 0f, w, h)
        canvas.drawRoundRect(rect, w / 2, w / 2, track)

        val r = w / 2 - 3f * d
        val top = 3f * d + r
        val bottom = h - 3f * d - r
        val cx = w / 2
        val cy = bottom - fraction * (bottom - top)
        val cw = w * 0.2f
        rect.set(cx - cw / 2, top, cx + cw / 2, bottom)
        canvas.drawRoundRect(rect, cw / 2, cw / 2, channel)
        rect.set(cx - cw / 2, cy, cx + cw / 2, bottom)
        canvas.drawRoundRect(rect, cw / 2, cw / 2, fill)

        canvas.drawCircle(cx, cy, r, knob)
        canvas.drawCircle(cx, cy, r, ring)
        canvas.drawCircle(cx, cy, 3f * d, dot)
    }
}
