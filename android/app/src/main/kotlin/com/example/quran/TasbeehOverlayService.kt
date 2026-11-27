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
import android.graphics.Path
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Rect
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
import android.view.Choreographer
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
 * Tap = +1. Drag to move it. While dragging, an X appears at the bottom of
 * the screen: let go over it to close the button (turn it on again from the
 * app's settings). Round design: the button is a circle, the top half of the
 * ring around it is the slider, and a bottom quarter shows the "x" combo.
 */
class TasbeehOverlayService : Service(), FloaterSpacing.Floater {

    companion object {
        /** The running service (null when the floating Tasbeeh is off). */
        @Volatile
        var instance: TasbeehOverlayService? = null
    }

    private lateinit var windowManager: WindowManager
    private var root: RingView? = null           // the whole round widget
    private var sliderLeft = true                // which side of the button the slider is on
    private var dragging = false                 // a finger is moving the widget
    private var screenW = 0                      // screen size the position was set for
    private var screenH = 0
    private var shownCombo = -1
    private var completing = false
    private var trash: FrameLayout? = null      // the close button's window
    private var closeView: CloseView? = null            // the circle with the X
    private val handler = Handler(Looper.getMainLooper())
    private lateinit var params: WindowManager.LayoutParams

    private val listener = SharedPreferences.OnSharedPreferenceChangeListener { _, _ -> refresh() }
    // the app's own settings (theme): recolour when they change
    private val themeListener = SharedPreferences.OnSharedPreferenceChangeListener { _, _ -> applyTheme() }
    private fun flutterPrefs() = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

    override fun onBind(intent: Intent?): IBinder? = null

    // the phone switched between light and dark (matters when the app follows
    // the phone), or was turned between upright and sideways
    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        applyTheme()
        onScreenResized()
    }

    /**
     * The phone was turned: the screen changed shape, so the old position could
     * be off screen. Keep the widget at the same relative place and fully visible.
     */
    private fun onScreenResized() {
        val v = root ?: return
        val m = OverlayArea.of(this)
        if (m.widthPixels == screenW && m.heightPixels == screenH) return
        // a drag gliding to a stop ends here, in the old layout
        settled?.let { settled = null; it() }
        Choreographer.getInstance().removeFrameCallback(frame)
        following = false
        if (screenW > 0 && screenH > 0) {
            val cx = (params.x + params.width / 2f) / screenW * m.widthPixels
            val cy = (params.y + params.height / 2f) / screenH * m.heightPixels
            params.x = (cx - params.width / 2f).toInt()
            params.y = (cy - params.height / 2f).toInt()
        }
        screenW = m.widthPixels
        screenH = m.heightPixels
        keepOnScreen()
        runCatching { windowManager.updateViewLayout(v, params) }
        saveSpot()
        // the bars and the camera cut-out can settle a moment after the turn: check again
        v.postDelayed({
            if (root !== v) return@postDelayed
            keepOnScreen()
            runCatching { windowManager.updateViewLayout(v, params) }
            saveSpot()
            FloaterSpacing.check(this)
        }, 500)
    }

    // ---------------------------------------------- keeping clear of the Companion
    override val busy get() = dragging || following
    /** The drawing (button + rings), without the empty margin around it. */
    override fun body(): Rect? {
        val v = root ?: return null
        val p = v.padPx
        return Rect(params.x + p, params.y + p, params.x + params.width - p, params.y + params.height - p)
    }
    override fun limits(): Rect {
        val v = root
        val ext = v?.padPx ?: 0
        val m = OverlayArea.of(this)
        val size = params.width
        return Rect(-ext, -ext, max(-ext, m.widthPixels - size + ext), max(-ext, m.heightPixels - size + ext))
    }
    override fun position() = Pair(params.x, params.y)
    override fun glideTo(x: Int, y: Int) {
        if (root == null) return
        px = params.x.toFloat(); py = params.y.toFloat()
        tx = x.toFloat(); ty = y.toFloat()
        settled = { saveSpot() }
        startFollow()
    }

    /** Remembers where the widget is (the saved place is the top-left of the BUTTON). */
    private fun saveSpot() {
        val size = params.width
        TasbeehStore.prefs(this).edit()
            .putInt("overlay_x", params.x + size / 2 - button / 2)
            .putInt("overlay_y", params.y + size / 2 - button / 2)
            .apply()
    }

    /**
     * Pulls the whole widget (button + rings) inside the current screen; only the
     * empty margin around the drawing may go past the edges (same rule as dragging).
     * Also turns the design to face the middle of the screen.
     */
    private fun keepOnScreen() {
        val v = root ?: return
        val m = OverlayArea.of(this)
        val size = params.width
        val ext = v.padPx
        params.x = params.x.coerceIn(-ext, max(-ext, m.widthPixels - size + ext))
        params.y = params.y.coerceIn(-ext, max(-ext, m.heightPixels - size + ext))
        val wantLeft = params.x + size / 2 > m.widthPixels / 2
        if (wantLeft != sliderLeft) {
            sliderLeft = wantLeft
            v.setSide(wantLeft)
        }
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
        instance = null
        Choreographer.getInstance().removeFrameCallback(frame)
        following = false
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
            .setContentText("Drag it to the X to close it")
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

    private val button get() = dp(90f)          // the round button (diameter), 25% bigger

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

    /** Dark theme: green button, cream rings. Light theme: the opposite. */
    private fun applyTheme() {
        root?.setDark(isDark())
    }

    private fun createOverlay() {
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager

        // ---- the close button (created first so the widget is drawn above it):
        // a circle with a white X. It grows 25% when the widget is over it.
        // The window is bigger than the circle, and it is where the absorption pulls.
        val close = CloseView(this)
        val bin = FrameLayout(this).apply {
            addView(close, FrameLayout.LayoutParams(dp(140f), dp(140f), Gravity.CENTER))
            visibility = View.GONE
        }
        closeView = close
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

        // ---- the round widget (button + slider ring + combo ring)
        val view = RingView(this)
        root = view
        val size = view.sizePx

        val metrics = OverlayArea.of(this)
        val saved = TasbeehStore.prefs(this)
        // the saved place is the top-left of the BUTTON
        val bx = saved.getInt("overlay_x", metrics.widthPixels - button - dp(16f))
        val by = saved.getInt("overlay_y", metrics.heightPixels / 3)
        val cx = bx + button / 2
        sliderLeft = cx > metrics.widthPixels / 2   // right half of the screen: slider on the left
        view.setSide(sliderLeft)

        params = WindowManager.LayoutParams(
            size, size,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = cx - size / 2
            y = by + button / 2 - size / 2
        }

        screenW = metrics.widthPixels
        screenH = metrics.heightPixels
        keepOnScreen()      // the saved place may be off this screen (e.g. saved while sideways)

        view.setOnTouchListener(touchListener(view))
        windowManager.addView(view, params)
        saved.registerOnSharedPreferenceChangeListener(listener)
        flutterPrefs().registerOnSharedPreferenceChangeListener(themeListener)
        applyTheme()
        refresh()
        instance = this
        view.post { FloaterSpacing.check(this) }   // it may appear on the Companion
    }

    private fun fraction(): Float {
        val target = max(1, TasbeehStore.target(this))
        return min(1f, TasbeehStore.count(this).toFloat() / target)
    }

    private fun setBar(combo: Int, pop: Boolean) {
        val arabic = TasbeehStore.arabicDigits(this)
        root?.setCombo(TasbeehStore.digits("x$combo", arabic), pop)
        shownCombo = combo
    }

    /**
     * The ring follows the count. When the chosen number is reached the ring
     * is full for a moment, the quarter pops to the next "x", and it empties.
     */
    private fun refresh() {
        val v = root ?: return
        val combo = TasbeehStore.combo(this)
        if (shownCombo < 0) {            // first time
            setBar(combo, false)
            v.setNow(fraction())
            return
        }
        if (combo > shownCombo) {        // the target was reached
            completing = true
            v.animateTo(1f)
            handler.postDelayed({
                completing = false
                setBar(TasbeehStore.combo(this), true)
                v.animateTo(fraction())
            }, 350)
            return
        }
        if (combo < shownCombo) setBar(combo, false) // reset from the app
        if (!completing) v.animateTo(fraction())
    }

    // ------------------------------------------------------------- the close button
    // Plain: a circle with a white X, no glow and no animation. When the
    // widget is over it (hover) it is 25% bigger.
    private fun setHover(on: Boolean) {
        closeView?.hover = on
    }

    private fun stopEffects() {
        closeView?.hover = false
    }

    // ------------------------------------------------------------- lagging drag
    // The widget does not jump to the finger: it glides after it (each frame it
    // covers a fraction of the remaining distance). Change FOLLOW for more or
    // less lag: 0.10 = very lazy, 0.35 = almost instant.
    private val follow = 0.18f
    private var tx = 0f                 // where the finger wants the widget
    private var ty = 0f
    private var px = 0f                 // where the widget really is
    private var py = 0f
    private var following = false
    private var settled: (() -> Unit)? = null
    private var overFire = false          // true = the fire has caught the widget

    // Fire "gravity": when the widget gets near the fire it is pulled in and
    // snapped to the middle of it; drag it further away to get it free again.
    private val catchDp = 95f           // centre-to-centre distance that catches it
    private val freeDp = 125f           // distance at which it lets go
    private val softDp = 60f            // how far outside the catch zone it starts to lean in
    private val pullSpeed = 0.10f       // smaller = slower, more gradual absorption

    private val frame = object : Choreographer.FrameCallback {
        override fun doFrame(frameTimeNanos: Long) {
            val v = root
            if (v == null) { following = false; return }

            // The widget's window position and the screen position can differ
            // (status bar, notch...), so measure the difference once per frame.
            val wl = IntArray(2)
            v.getLocationOnScreen(wl)
            val offX = wl[0] - params.x
            val offY = wl[1] - params.y
            val half = params.width / 2f

            // the fire's middle, in the widget's own window coordinates
            val bin = trash
            val fireOn = bin != null && bin.visibility == View.VISIBLE && bin.width > 0
            var fireX = 0f
            var fireY = 0f
            if (fireOn) {
                val a = IntArray(2)
                bin!!.getLocationOnScreen(a)
                fireX = a[0] + bin.width / 2f - offX
                fireY = a[1] + bin.height / 2f - offY
            }

            // gravity: judged by where the FINGER wants the widget
            if (fireOn) {
                val dist = hypot(tx + half - fireX, ty + half - fireY)
                val now = if (overFire) dist < dp(freeDp) else dist < dp(catchDp)
                if (now != overFire) {
                    overFire = now
                    setHover(now)
                    if (now) v.performHapticFeedback(HapticFeedbackConstants.LONG_PRESS)
                }
            } else if (overFire && trash?.visibility != View.VISIBLE) {
                overFire = false
            }

            // goal: the middle of the fire when caught, otherwise the finger
            var gx = tx
            var gy = ty
            var speed = follow
            if (fireOn) {
                val dist = hypot(tx + half - fireX, ty + half - fireY)
                if (overFire) {
                    // caught: drift slowly into the middle of the fire
                    gx = fireX - half
                    gy = fireY - half
                    speed = pullSpeed
                } else if (dist < dp(catchDp + softDp)) {
                    // just outside: a gentle lean towards the fire that grows as you get closer
                    val w = 0.4f * (1f - (dist - dp(catchDp)) / dp(softDp))
                    gx = tx + (fireX - half - tx) * w
                    gy = ty + (fireY - half - ty) * w
                }
            }

            val dx = gx - px
            val dy = gy - py
            val arrived = abs(dx) < 1f && abs(dy) < 1f
            if (arrived) { px = gx; py = gy } else { px += dx * speed; py += dy * speed }
            params.x = px.toInt()
            params.y = py.toInt()

            // mirror the design when the widget crosses the middle of the screen
            val m = OverlayArea.of(this@TasbeehOverlayService)
            val wantLeft = params.x + params.width / 2 > m.widthPixels / 2
            if (wantLeft != sliderLeft) {
                sliderLeft = wantLeft
                v.setSide(wantLeft)
            }
            runCatching { windowManager.updateViewLayout(v, params) }

            if (arrived) {
                following = false
                settled?.let { settled = null; it() }
            } else {
                Choreographer.getInstance().postFrameCallback(this)
            }
        }
    }

    private fun startFollow() {
        if (following) return
        following = true
        Choreographer.getInstance().postFrameCallback(frame)
    }

    // ------------------------------------------------------------- touching
    /** Tap the button = +1, drag anywhere = move, let go over the fire = close. */
    private fun touchListener(view: RingView): View.OnTouchListener {
        val slop = ViewConfiguration.get(this).scaledTouchSlop
        var downX = 0f
        var downY = 0f
        var startX = 0
        var startY = 0
        var onButton = false

        fun center(v: View): Pair<Float, Float> {
            val loc = IntArray(2)
            v.getLocationOnScreen(loc)
            return Pair(loc[0] + v.width / 2f, loc[1] + v.height / 2f)
        }

        return View.OnTouchListener { _, e ->
            when (e.action) {
                MotionEvent.ACTION_DOWN -> {
                    // a drag that is still gliding to a stop ends right now
                    settled?.let { settled = null; it() }
                    downX = e.rawX; downY = e.rawY
                    startX = params.x; startY = params.y
                    px = params.x.toFloat(); py = params.y.toFloat()
                    tx = px; ty = py
                    dragging = false
                    overFire = false
                    val (cx, cy) = center(view)
                    onButton = hypot(e.rawX - cx, e.rawY - cy) <= dp(50f)
                    if (onButton) view.setPressedLook(true)
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = e.rawX - downX
                    val dy = e.rawY - downY
                    if (!dragging && (abs(dx) > slop || abs(dy) > slop)) {
                        dragging = true
                        view.setPressedLook(false)
                        trash?.visibility = View.VISIBLE
                        setHover(false)
                    }
                    if (dragging) {
                        val m = OverlayArea.of(this)
                        val size = params.width
                        // the whole widget (button + both rings) stays on screen: only the
                        // empty margin around the drawing may go past the edges
                        val ext = view.padPx
                        tx = (startX + dx).coerceIn(-ext.toFloat(), (m.widthPixels - size + ext).toFloat())
                        ty = (startY + dy).coerceIn(-ext.toFloat(), (m.heightPixels - size + ext).toFloat())
                        startFollow()
                    }
                    true
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    view.setPressedLook(false)
                    if (!dragging) {
                        if (e.action == MotionEvent.ACTION_UP && onButton) {
                            TasbeehStore.increment(this)
                        }
                    } else {
                        // let the widget finish gliding to the finger, then decide
                        settled = {
                            trash?.visibility = View.GONE
                            stopEffects()
                            if (overFire) {
                                TasbeehStore.setOverlayEnabled(this, false)
                                stopSelf()
                            } else {
                                saveSpot()
                                dragging = false
                                FloaterSpacing.check(this)   // dropped on the Companion: move apart
                            }
                            dragging = false
                        }
                        startFollow()
                    }
                    true
                }
                else -> false
            }
        }
    }
}

/**
 * The whole round widget in one view:
 *  - a round 3D button in the middle (edges raised, middle sunk),
 *  - the slider: the TOP half of the ring. It starts on the side next to the
 *    screen edge and fills over the top towards the middle of the screen
 *    (widget on the right half: from the right side round to the left),
 *  - the "x" combo: the bottom quarter on the side facing the middle of the
 *    screen (widget on the right half: bottom-left).
 * Everything is mirrored when the widget is on the left half.
 */
private class RingView(context: Context) : View(context) {
    private val d = resources.displayMetrics.density * 1.25f   // everything 25% bigger
    private val buttonR = 36f * d
    private val gap = 4f * d
    private val comboT = 20f * d
    private val sliderT = comboT        // the slider is as thick as the combo
    private val pad = 6f * d
    val sizePx = ((buttonR + gap + comboT + pad) * 2).toInt()
    val padPx = pad.toInt()          // empty margin around the drawing inside the window

    private var left = true            // widget on the right half (slider ends on the left)
    private var dark = true
    private var fraction = 0f
    private var animator: ValueAnimator? = null
    private var comboText = "x0"
    private var pop = 0f
    private var popAnimator: ValueAnimator? = null
    private var pressScale = 1f
    private var pressAnimator: ValueAnimator? = null

    private val track = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE; strokeCap = Paint.Cap.ROUND; strokeWidth = sliderT
    }
    // the groove and the fill are thinner than the track: they sit INSIDE it
    private val channel = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE; strokeCap = Paint.Cap.ROUND; strokeWidth = sliderT * 0.3f
    }
    private val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE; strokeCap = Paint.Cap.ROUND; strokeWidth = sliderT * 0.3f
    }
    private val comboPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE; strokeCap = Paint.Cap.ROUND; strokeWidth = comboT
        setShadowLayer(3f * d, 0f, 1.5f * d, Color.parseColor("#55000000"))
    }
    private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        textSize = 14f * d
        typeface = Typeface.DEFAULT_BOLD
    }
    private val knob = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        setShadowLayer(3f * d, 0f, 1.5f * d, Color.parseColor("#55000000"))
    }
    private val knobRing = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE; strokeWidth = 2f * d
    }
    private val face = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        setShadowLayer(5f * d, 0f, 2.5f * d, Color.parseColor("#66000000"))
    }
    private val dish = Paint(Paint.ANTI_ALIAS_FLAG)
    private val dot = Paint(Paint.ANTI_ALIAS_FLAG)
    private val oval = RectF()
    private val path = Path()

    init {
        setLayerType(LAYER_TYPE_SOFTWARE, null) // needed for the soft shadows
        setDark(true)
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        setMeasuredDimension(sizePx, sizePx)
    }

    fun setSide(sliderLeft: Boolean) {
        left = sliderLeft
        invalidate()
    }

    fun setDark(isDark: Boolean) {
        dark = isDark
        val cream = Color.parseColor("#F7EBD4")
        val teal = Color.parseColor("#12685E")
        if (dark) {
            track.color = cream             // same colour as the combo
            channel.color = Color.parseColor("#CBBD9B")
            fill.color = teal
            knob.color = cream; knobRing.color = teal; dot.color = teal
            comboPaint.color = cream; textPaint.color = teal
        } else {
            track.color = teal
            channel.color = Color.parseColor("#0A3D37")
            fill.color = cream
            knob.color = teal; knobRing.color = cream; dot.color = cream
            comboPaint.color = teal; textPaint.color = cream
        }
        invalidate()
    }

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

    fun setCombo(text: String, popIt: Boolean) {
        comboText = text
        popAnimator?.cancel()
        if (popIt) {
            popAnimator = ValueAnimator.ofFloat(0f, 1f, 0f).apply {
                duration = 320
                addUpdateListener { pop = it.animatedValue as Float; invalidate() }
                start()
            }
        } else {
            pop = 0f
            invalidate()
        }
    }

    fun setPressedLook(on: Boolean) {
        pressAnimator?.cancel()
        pressAnimator = ValueAnimator.ofFloat(pressScale, if (on) 0.95f else 1f).apply {
            duration = 80
            addUpdateListener { pressScale = it.animatedValue as Float; invalidate() }
            start()
        }
    }

    /** Angle (degrees) that the rounded end of a ring takes up, plus a small gap. */
    private fun edge(radius: Float, thickness: Float) =
        Math.toDegrees((thickness / 2f / radius).toDouble()).toFloat() + 4f

    override fun onDraw(canvas: Canvas) {
        val cx = width / 2f
        val cy = height / 2f

        // ---- the slider: the top half of the ring, filling over the top.
        // Angles: 0 = right, 90 = bottom, 180 = left, 270 = top; + = clockwise.
        // Right half of the screen: starts at the right (0) and goes
        // anticlockwise over the top to the left (180). Left half: mirrored.
        val rs = buttonR + gap + sliderT / 2f
        val e = edge(rs, sliderT)
        val start = if (left) -e else 180f + e
        val dir = if (left) -1f else 1f
        val total = 180f - 2f * e
        oval.set(cx - rs, cy - rs, cx + rs, cy + rs)
        canvas.drawArc(oval, start, dir * total, false, track)
        canvas.drawArc(oval, start, dir * total, false, channel)
        if (fraction > 0.001f) {
            canvas.drawArc(oval, start, dir * total * fraction, false, fill)
        }
        val a = Math.toRadians((start + dir * total * fraction).toDouble())
        val kx = cx + rs * Math.cos(a).toFloat()
        val ky = cy + rs * Math.sin(a).toFloat()
        val kr = sliderT / 2f - 2.5f * d          // the knob stays inside the track
        canvas.drawCircle(kx, ky, kr, knob)
        canvas.drawCircle(kx, ky, kr, knobRing)
        canvas.drawCircle(kx, ky, 2.5f * d, dot)

        // ---- the combo: the bottom quarter facing the middle of the screen
        val rc = buttonR + gap + comboT / 2f
        val ec = edge(rc, comboT)
        val startQ = if (left) 90f else 0f       // bottom-left, or bottom-right when mirrored
        canvas.save()
        val s = 1f + 0.12f * pop
        canvas.scale(s, s, cx, cy)
        oval.set(cx - rc, cy - rc, cx + rc, cy + rc)
        canvas.drawArc(oval, startQ + ec, 90f - 2f * ec, false, comboPaint)
        // the text follows the curve and reads left to right: along the bottom
        // the path runs anticlockwise, so the letters stand upright with their
        // tops towards the button; the baseline sits on the outer side of the
        // ring's middle so the text is centred in the ring
        val rt = rc + textPaint.textSize * 0.36f
        oval.set(cx - rt, cy - rt, cx + rt, cy + rt)
        path.reset()
        path.addArc(oval, startQ + 90f, -90f)
        val arcLen = rt * Math.PI.toFloat() / 2f
        val offset = max(0f, (arcLen - textPaint.measureText(comboText)) / 2f)
        canvas.drawTextOnPath(comboText, path, offset, 0f, textPaint)
        canvas.restore()

        // ---- the round 3D button: raised edge, sunk middle
        canvas.save()
        canvas.scale(pressScale, pressScale, cx, cy)
        val c1 = if (dark) "#1A7C71" else "#FFFAEC"
        val c2 = if (dark) "#0E4F47" else "#E0CFA8"
        face.shader = LinearGradient(cx - buttonR, cy - buttonR, cx + buttonR, cy + buttonR,
            Color.parseColor(c1), Color.parseColor(c2), Shader.TileMode.CLAMP)
        canvas.drawCircle(cx, cy, buttonR, face)
        val r2 = buttonR - 7f * d
        val d1 = if (dark) "#0F554C" else "#E8DABA"
        val d2 = if (dark) "#167267" else "#F8EFD9"
        dish.shader = LinearGradient(cx - r2, cy - r2, cx + r2, cy + r2,
            Color.parseColor(d1), Color.parseColor(d2), Shader.TileMode.CLAMP)
        canvas.drawCircle(cx, cy, r2, dish)
        canvas.restore()
    }
}


/**
 * The close target for the floating Tasbeeh and the Companion: a circle with a
 * white X, in Android's own colours (like the system's bubble dismiss target:
 * the phone's dark neutral on Android 12+, dark grey before). 25% bigger while
 * the widget is over it.
 */
internal class CloseView(context: Context) : View(context) {
    private val d = resources.displayMetrics.density
    private val circle = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = if (Build.VERSION.SDK_INT >= 31)
            context.getColor(android.R.color.system_neutral1_800)
        else Color.parseColor("#FF3C4043")
        alpha = 235
    }
    private val cross = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
    }

    var hover = false
        set(value) {
            if (field != value) {
                field = value
                invalidate()
            }
        }

    override fun onDraw(canvas: Canvas) {
        val cx = width / 2f
        val cy = height / 2f
        val k = if (hover) 1.25f else 1f
        canvas.drawCircle(cx, cy, 32f * d * k, circle)
        cross.strokeWidth = 3.4f * d * k
        val a = 11f * d * k
        canvas.drawLine(cx - a, cy - a, cx + a, cy + a, cross)
        canvas.drawLine(cx + a, cy - a, cx - a, cy + a, cross)
    }
}
