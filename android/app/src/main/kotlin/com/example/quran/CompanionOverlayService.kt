package com.example.quran

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Path
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.Rect
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
import kotlin.math.abs
import kotlin.math.hypot
import kotlin.math.max

/**
 * "Companion mode": a little pixel character that floats on top of other apps.
 *  - the artwork looks to the RIGHT, so it sits on the left half of the screen;
 *    dragged to the right half it flips and looks to the LEFT
 *  - it bobs its head (idle animation)
 *  - drag it anywhere; it remembers its place
 *  - while dragging, an X appears at the bottom of the screen: let go over it
 *    to turn the companion off (like the floating Tasbeeh)
 * It is turned on and off from the app's settings.
 */
class CompanionOverlayService : Service(), FloaterSpacing.Floater {

    companion object {
        const val ACTION_SAY = "werd.companion.say"

        /** The running service (null when the companion is off). */
        @Volatile
        var instance: CompanionOverlayService? = null
    }

    private lateinit var windowManager: WindowManager
    private var view: CompanionView? = null
    private lateinit var params: WindowManager.LayoutParams
    private val handler = Handler(Looper.getMainLooper())
    private var bobbing: Runnable? = null
    private var bubble: BubbleView? = null
    private var bubbleParams: WindowManager.LayoutParams? = null
    private var hideBubble: Runnable? = null
    private var trash: FrameLayout? = null      // the close target's window
    private var closeView: CloseView? = null
    private var overBin = false                 // the companion is over the X
    private var dragging = false                // a finger is moving the companion
    private var screenW = 0                     // screen size the position was set for
    private var screenH = 0

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startAsForeground()
        if (!Settings.canDrawOverlays(this)) {
            stopSelf()
            return START_NOT_STICKY
        }
        instance = this
        if (view == null) createOverlay()
        if (intent?.action == ACTION_SAY) {
            intent.getStringExtra("text")?.let { say(it, 8000) }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        instance = null
        hideBubbleNow()
        bobbing?.let { handler.removeCallbacks(it) }
        Choreographer.getInstance().removeFrameCallback(frame)
        settled = null
        view?.let { runCatching { windowManager.removeView(it) } }
        view = null
        trash?.let { runCatching { windowManager.removeView(it) } }
        trash = null
        super.onDestroy()
    }

    private fun dp(value: Float) =
        TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, value, resources.displayMetrics).toInt()

    // ---------------------------------------------------------- notification
    private fun startAsForeground() {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(
                NotificationChannel("companion_overlay", "Companion", NotificationManager.IMPORTANCE_MIN)
            )
        }
        val open = PendingIntent.getActivity(
            this, 0, packageManager.getLaunchIntentForPackage(packageName),
            PendingIntent.FLAG_IMMUTABLE
        )
        val builder = if (Build.VERSION.SDK_INT >= 26)
            Notification.Builder(this, "companion_overlay") else Notification.Builder(this)
        val notification = builder
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle("Your companion is on")
            .setContentText("Drag it to the X to close it")
            .setContentIntent(open)
            .setOngoing(true)
            .build()
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(4243, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(4243, notification)
        }
    }

    // --------------------------------------------------------------- overlay
    /**
     * A picture of the companion. It comes from the app's own files (the app
     * copies them there from its assets, so they are changed in one place only).
     * An old copy in the Android res folder is used only if that is missing.
     */
    private fun loadPicture(name: String, opts: BitmapFactory.Options): Bitmap? =
        CompanionStore.loadPicture(this, name, opts)

    private fun createOverlay() {
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager

        val type = CompanionStore.type(this)                       // "sheikh" or "sister"
        val opts = BitmapFactory.Options().apply { inScaled = false }
        val bitmap = loadPicture("${type}_body", opts)   // the body, without the head
        if (bitmap == null) { stopSelf(); return }

        // the head on its own (cut along the real outline of the head)
        val head = loadPicture("${type}_head", opts)
        val heightPx = dp(130f)
        val widthPx = (bitmap.width * heightPx.toFloat() / bitmap.height).toInt()
        val bob = dp(3f)

        // the close target (added first so the companion is drawn above it),
        // shown only while dragging; same as the floating Tasbeeh's
        val close = CloseView(this)
        val bin = FrameLayout(this).apply {
            addView(close, FrameLayout.LayoutParams(dp(140f), dp(140f), Gravity.CENTER))
            visibility = View.GONE
        }
        closeView = close
        windowManager.addView(bin, WindowManager.LayoutParams(
            dp(140f), dp(140f),
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
            y = dp(26f)
        })
        trash = bin

        val v = CompanionView(this, bitmap, head, widthPx, heightPx, bob)
        view = v

        val m = OverlayArea.of(this)
        val prefs = CompanionStore.prefs(this)
        params = WindowManager.LayoutParams(
            widthPx, heightPx + bob,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = prefs.getInt("x", dp(12f))            // starts on the left half
            y = prefs.getInt("y", (m.heightPixels * 0.62f).toInt())
        }
        screenW = m.widthPixels
        screenH = m.heightPixels
        keepOnScreen()      // the saved place may be off this screen (e.g. phone sideways)
        v.scaleX = if (params.x + widthPx / 2 > m.widthPixels / 2) -1f else 1f
        v.setOnTouchListener(touchListener(v))
        windowManager.addView(v, params)
        startBobbing(v)
        v.post { FloaterSpacing.check(this) }   // it may appear on the Tasbeeh
    }

    // -------------------------------------------------------------- rotation
    /**
     * The phone was turned (portrait <-> landscape): the screen changed shape,
     * so the old position could be off screen. Keep the companion at the same
     * relative place (e.g. 60% down, near the right edge) and fully visible.
     */
    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        val v = view ?: return
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
        v.scaleX = if (params.x + params.width / 2 > m.widthPixels / 2) -1f else 1f
        runCatching { windowManager.updateViewLayout(v, params) }
        bubble?.let { b ->
            val lp = bubbleParams
            if (b.parent != null && lp != null) {
                placeBubble(b, lp)
                runCatching { windowManager.updateViewLayout(b, lp) }
            }
        }
        CompanionStore.prefs(this).edit().putInt("x", params.x).putInt("y", params.y).apply()
        // the bars and the camera cut-out can settle a moment after the turn: check again
        v.postDelayed({
            if (view !== v) return@postDelayed
            keepOnScreen()
            v.scaleX = if (params.x + params.width / 2 > OverlayArea.of(this).widthPixels / 2) -1f else 1f
            runCatching { windowManager.updateViewLayout(v, params) }
            CompanionStore.prefs(this).edit().putInt("x", params.x).putInt("y", params.y).apply()
            FloaterSpacing.check(this)
        }, 500)
    }

    // ---------------------------------------------- keeping clear of the Tasbeeh
    override val busy get() = dragging || following
    override fun body(): Rect? =
        if (view == null) null else Rect(params.x, params.y, params.x + params.width, params.y + params.height)
    override fun limits(): Rect {
        val m = OverlayArea.of(this)
        return Rect(0, 0, max(0, m.widthPixels - params.width), max(0, m.heightPixels - params.height))
    }
    override fun position() = Pair(params.x, params.y)
    override fun glideTo(x: Int, y: Int) {
        if (view == null) return
        px = params.x.toFloat(); py = params.y.toFloat()
        tx = x.toFloat(); ty = y.toFloat()
        settled = { CompanionStore.prefs(this).edit().putInt("x", params.x).putInt("y", params.y).apply() }
        startFollow()
    }

    /** Pulls the companion fully inside the current screen. */
    private fun keepOnScreen() {
        val m = OverlayArea.of(this)
        params.x = params.x.coerceIn(0, max(0, m.widthPixels - params.width))
        params.y = params.y.coerceIn(0, max(0, m.heightPixels - params.height))
    }

    // ----------------------------------------------------------- speech bubble
    /** Shows [text] in a speech bubble above the companion for [ms] milliseconds. */
    fun say(text: String, ms: Long = 1000) {
        handler.post {
            val companion = view ?: return@post
            if (!CompanionStore.bubbles(this)) return@post
            val b = bubble ?: BubbleView(this) { hideBubbleNow() }.also { bubble = it }
            b.setContent(text)
            val m = OverlayArea.of(this)
            b.measure(
                View.MeasureSpec.makeMeasureSpec(m.widthPixels - dp(24f), View.MeasureSpec.AT_MOST),
                View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)
            )
            val lp = bubbleParams ?: WindowManager.LayoutParams(
                WindowManager.LayoutParams.WRAP_CONTENT, WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                PixelFormat.TRANSLUCENT
            ).apply { gravity = Gravity.TOP or Gravity.START }.also { bubbleParams = it }
            placeBubble(b, lp)
            if (b.parent == null) windowManager.addView(b, lp) else windowManager.updateViewLayout(b, lp)
            hideBubble?.let { handler.removeCallbacks(it) }
            val r = Runnable { hideBubbleNow() }
            hideBubble = r
            handler.postDelayed(r, ms)
        }
    }

    /** Keeps the bubble above the companion's head, inside the screen. */
    private fun placeBubble(b: BubbleView, lp: WindowManager.LayoutParams) {
        val m = OverlayArea.of(this)
        val margin = dp(8f)
        val bw = b.measuredWidth
        val bh = b.measuredHeight
        val cx = params.x + params.width / 2
        val x = (cx - bw / 2).coerceIn(margin, max(margin, m.widthPixels - bw - margin))
        lp.x = x
        lp.y = max(0, params.y - bh + dp(4f) + b.edgePad)
        b.pointTailAt(cx - (x + bw / 2))
    }

    /** Removes the bubble at once. */
    private fun hideBubbleNow() {
        hideBubble?.let { handler.removeCallbacks(it) }
        hideBubble = null
        val b = bubble ?: return
        if (b.parent != null) runCatching { windowManager.removeView(b) }
    }

    /** Idle animation: the head goes down a little and comes back, like breathing. */
    private fun startBobbing(v: CompanionView) {
        val r = object : Runnable {
            override fun run() {
                v.toggleBob()
                handler.postDelayed(this, 550)
            }
        }
        bobbing = r
        handler.postDelayed(r, 550)
    }

    // ------------------------------------------------------------- lagging drag
    // Same feel as the floating Tasbeeh: the companion does not jump to the
    // finger, it glides after it (each frame it covers a fraction of the
    // remaining distance). FOLLOW: 0.10 = very lazy, 0.35 = almost instant.
    private val follow = 0.18f
    private var tx = 0f                 // where the finger wants the companion
    private var ty = 0f
    private var px = 0f                 // where the companion really is
    private var py = 0f
    private var following = false
    private var settled: (() -> Unit)? = null

    // The X's "gravity" (same numbers as the Tasbeeh): near the X the companion
    // is pulled in and eased into its middle; drag it further away to free it.
    private val catchDp = 95f           // centre-to-centre distance that catches it
    private val freeDp = 125f           // distance at which it lets go
    private val softDp = 60f            // how far outside the catch zone it starts to lean in
    private val pullSpeed = 0.10f       // smaller = slower, more gradual absorption

    /** The X's middle in the companion window's own coordinates, or null while it is hidden. */
    private fun binCentre(v: CompanionView): Pair<Float, Float>? {
        val bin = trash ?: return null
        if (bin.visibility != View.VISIBLE || bin.width == 0) return null
        // window position and screen position can differ (status bar, notch...)
        val loc = IntArray(2)
        v.getLocationOnScreen(loc)
        // on the right half the picture is mirrored (scaleX = -1), and Android
        // then reports its right edge as the left one: undo that
        val left = if (v.scaleX < 0f) loc[0] - v.width else loc[0]
        val offX = left - params.x
        val offY = loc[1] - params.y
        val b = IntArray(2)
        bin.getLocationOnScreen(b)
        return Pair(b[0] + bin.width / 2f - offX, b[1] + bin.height / 2f - offY)
    }

    private val frame = object : Choreographer.FrameCallback {
        override fun doFrame(frameTimeNanos: Long) {
            val v = view
            if (v == null) { following = false; return }
            val halfW = params.width / 2f
            val halfH = params.height / 2f

            // goal: the finger, or the middle of the X when caught
            var gx = tx
            var gy = ty
            var speed = follow
            val bin = binCentre(v)
            if (bin != null) {
                val (fx, fy) = bin
                // gravity is judged by where the FINGER wants the companion
                val dist = hypot(tx + halfW - fx, ty + halfH - fy)
                val now = if (overBin) dist < dp(freeDp) else dist < dp(catchDp)
                if (now != overBin) {
                    overBin = now
                    closeView?.hover = now
                    if (now) v.performHapticFeedback(HapticFeedbackConstants.LONG_PRESS)
                }
                if (overBin) {
                    // caught: drift slowly into the middle of the X
                    gx = fx - halfW
                    gy = fy - halfH
                    speed = pullSpeed
                } else if (dist < dp(catchDp + softDp)) {
                    // just outside: a gentle lean towards the X that grows as you get closer
                    val w = 0.4f * (1f - (dist - dp(catchDp)) / dp(softDp))
                    gx = tx + (fx - halfW - tx) * w
                    gy = ty + (fy - halfH - ty) * w
                }
            }

            val dx = gx - px
            val dy = gy - py
            val arrived = abs(dx) < 1f && abs(dy) < 1f
            if (arrived) { px = gx; py = gy } else { px += dx * speed; py += dy * speed }
            params.x = px.toInt()
            params.y = py.toInt()

            // left half: looks right (as drawn). right half: flipped, looks left.
            val m = OverlayArea.of(this@CompanionOverlayService)
            v.scaleX = if (params.x + params.width / 2 > m.widthPixels / 2) -1f else 1f
            runCatching { windowManager.updateViewLayout(v, params) }
            bubble?.let { b ->
                val lp = bubbleParams
                if (b.parent != null && lp != null) {
                    placeBubble(b, lp)
                    runCatching { windowManager.updateViewLayout(b, lp) }
                }
            }

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

    /** Drag = move (gliding after the finger); let go over the X = turn the companion off. */
    private fun touchListener(v: CompanionView): View.OnTouchListener {
        val slop = ViewConfiguration.get(this).scaledTouchSlop
        var downX = 0f
        var downY = 0f
        var startX = 0
        var startY = 0
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
                    overBin = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = e.rawX - downX
                    val dy = e.rawY - downY
                    if (!dragging && (abs(dx) > slop || abs(dy) > slop)) {
                        dragging = true
                        trash?.visibility = View.VISIBLE
                        closeView?.hover = false
                    }
                    if (dragging) {
                        val m = OverlayArea.of(this)
                        tx = (startX + dx).coerceIn(0f, max(0, m.widthPixels - params.width).toFloat())
                        ty = (startY + dy).coerceIn(0f, max(0, m.heightPixels - params.height).toFloat())
                        startFollow()
                    }
                    true
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    if (dragging) {
                        // let the companion finish gliding, then decide
                        settled = {
                            trash?.visibility = View.GONE
                            closeView?.hover = false
                            if (overBin) {
                                // let go over the X: the companion is turned off
                                // (turn it on again from the app's settings)
                                overBin = false
                                CompanionStore.setEnabled(this, false)
                                stopSelf()
                            } else {
                                CompanionStore.prefs(this).edit()
                                    .putInt("x", params.x).putInt("y", params.y).apply()
                                dragging = false
                                FloaterSpacing.check(this)   // dropped on the Tasbeeh: move apart
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
 * Draws the pixel character in two pieces: the body (without the head) and the
 * head (cut along its exact outline). At rest the head sits in its place;
 * when the head is "down" it is drawn [bobPx] lower, so only the head bobs.
 * No smoothing: the pixels stay sharp.
 */
internal class CompanionView(
    context: Context,
    private val body: Bitmap,
    private val head: Bitmap?,
    private val w: Int,
    private val h: Int,
    private val bobPx: Int,
) : View(context) {

    private val paint = Paint().apply { isFilterBitmap = false; isAntiAlias = false; isDither = false }
    private var down = false
    private val bodyRect = Rect(0, 0, w, h)
    private val headUp = Rect(0, 0, w, h)
    private val headDown = Rect(0, bobPx, w, h + bobPx)

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        setMeasuredDimension(w, h + bobPx)
    }

    fun toggleBob() {
        down = !down
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        canvas.drawBitmap(body, null, bodyRect, paint)
        if (head != null) canvas.drawBitmap(head, null, if (down) headDown else headUp, paint)
    }
}

/** The speech bubble: rounded box with a little tail that points at the companion. */
internal class BubbleView(context: Context, onTap: () -> Unit) : LinearLayout(context) {
    private val d = resources.displayMetrics.density
    private val text = TextView(context)
    private val tail = TailView(context)

    /** Empty room around the bubble so the pop animation is not cut off by the window. */
    val edgePad = (16 * d).toInt()

    init {
        orientation = VERTICAL
        gravity = Gravity.CENTER_HORIZONTAL
        setPadding(edgePad, edgePad, edgePad, edgePad)
        text.apply {
            setTextColor(Color.parseColor("#0E4F47"))
            textSize = 15f
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            textDirection = View.TEXT_DIRECTION_FIRST_STRONG
            maxWidth = (240 * d).toInt()
            setPadding((14 * d).toInt(), (9 * d).toInt(), (14 * d).toInt(), (9 * d).toInt())
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#F7EBD4"))
                cornerRadius = 16 * d
                setStroke((2 * d).toInt(), Color.parseColor("#12685E"))
            }
        }
        addView(text, LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT))
        addView(tail, LayoutParams((18 * d).toInt(), (10 * d).toInt()).apply { topMargin = (-2 * d).toInt() })
        setOnClickListener { onTap() }
    }

    fun setContent(t: String) {
        text.text = t
    }

    /** [dx] = how far (px) the companion's middle is from the middle of the bubble. */
    fun pointTailAt(dx: Int) {
        val limit = (text.measuredWidth / 2 - 22 * d).coerceAtLeast(0f)
        tail.translationX = dx.toFloat().coerceIn(-limit, limit)
    }
}

private class TailView(context: Context) : View(context) {
    private val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.parseColor("#F7EBD4") }
    private val linePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#12685E")
        style = Paint.Style.STROKE
        strokeWidth = 2f * resources.displayMetrics.density
        strokeJoin = Paint.Join.ROUND
    }
    private val path = Path()

    override fun onDraw(canvas: Canvas) {
        val w = width.toFloat()
        val h = height.toFloat()
        val sw = linePaint.strokeWidth / 2f
        path.reset()
        path.moveTo(sw, 0f)
        path.lineTo(w / 2f, h - sw)
        path.lineTo(w - sw, 0f)
        canvas.drawRect(sw, 0f, w - sw, 3f, fillPaint)   // hides the bubble's border above the tail
        val fill = Path(path).apply { close() }
        canvas.drawPath(fill, fillPaint)
        canvas.drawPath(path, linePaint)
    }
}
