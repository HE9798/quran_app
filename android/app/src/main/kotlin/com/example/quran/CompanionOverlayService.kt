package com.example.quran

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Path
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
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
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowManager
import kotlin.math.abs
import kotlin.math.max

/**
 * "Companion mode": a little pixel character that floats on top of other apps.
 *  - the artwork looks to the RIGHT, so it sits on the left half of the screen;
 *    dragged to the right half it flips and looks to the LEFT
 *  - it bobs its head (idle animation)
 *  - drag it anywhere; it remembers its place
 * It is turned on and off from the app's settings.
 */
class CompanionOverlayService : Service() {

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
        view?.let { runCatching { windowManager.removeView(it) } }
        view = null
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
            .setContentText("Turn it off from the app's settings")
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
    private fun loadPicture(name: String, opts: BitmapFactory.Options): Bitmap? {
        val file = CompanionStore.imageFile(this, name)
        if (file.exists()) {
            val bitmap = BitmapFactory.decodeFile(file.absolutePath, opts)
            if (bitmap != null) return bitmap
        }
        val id = resources.getIdentifier("companion_$name", "drawable", packageName)
        return if (id != 0) BitmapFactory.decodeResource(resources, id, opts) else null
    }

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

        val v = CompanionView(this, bitmap, head, widthPx, heightPx, bob)
        view = v

        val m = resources.displayMetrics
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
        v.scaleX = if (params.x + widthPx / 2 > m.widthPixels / 2) -1f else 1f
        v.setOnTouchListener(touchListener(v))
        windowManager.addView(v, params)
        startBobbing(v)
    }

    // ----------------------------------------------------------- speech bubble
    /** Shows [text] in a speech bubble above the companion for [ms] milliseconds. */
    fun say(text: String, ms: Long = 1000) {
        handler.post {
            val companion = view ?: return@post
            if (!CompanionStore.bubbles(this)) return@post
            val b = bubble ?: BubbleView(this) { hideBubbleNow() }.also { bubble = it }
            b.setContent(text)
            val m = resources.displayMetrics
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
        val m = resources.displayMetrics
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

    private fun touchListener(v: CompanionView): View.OnTouchListener {
        val slop = ViewConfiguration.get(this).scaledTouchSlop
        var downX = 0f
        var downY = 0f
        var startX = 0
        var startY = 0
        var dragging = false
        return View.OnTouchListener { _, e ->
            when (e.action) {
                MotionEvent.ACTION_DOWN -> {
                    downX = e.rawX; downY = e.rawY
                    startX = params.x; startY = params.y
                    dragging = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = e.rawX - downX
                    val dy = e.rawY - downY
                    if (!dragging && (abs(dx) > slop || abs(dy) > slop)) dragging = true
                    if (dragging) {
                        val m = resources.displayMetrics
                        params.x = (startX + dx.toInt()).coerceIn(0, max(0, m.widthPixels - params.width))
                        params.y = (startY + dy.toInt()).coerceIn(0, max(0, m.heightPixels - params.height))
                        // left half: looks right (as drawn). right half: flipped, looks left.
                        v.scaleX = if (params.x + params.width / 2 > m.widthPixels / 2) -1f else 1f
                        windowManager.updateViewLayout(v, params)
                        bubble?.let { b ->
                            val lp = bubbleParams
                            if (b.parent != null && lp != null) {
                                placeBubble(b, lp)
                                windowManager.updateViewLayout(b, lp)
                            }
                        }
                    }
                    true
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    if (dragging) {
                        CompanionStore.prefs(this).edit()
                            .putInt("x", params.x).putInt("y", params.y).apply()
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
private class CompanionView(
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
private class BubbleView(context: Context, onTap: () -> Unit) : LinearLayout(context) {
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
