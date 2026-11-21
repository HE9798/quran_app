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

    private lateinit var windowManager: WindowManager
    private var view: CompanionView? = null
    private lateinit var params: WindowManager.LayoutParams
    private val handler = Handler(Looper.getMainLooper())
    private var bobbing: Runnable? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startAsForeground()
        if (!Settings.canDrawOverlays(this)) {
            stopSelf()
            return START_NOT_STICKY
        }
        if (view == null) createOverlay()
        return START_STICKY
    }

    override fun onDestroy() {
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
    private fun createOverlay() {
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager

        val type = CompanionStore.type(this)                       // "sheikh" or "sister"
        val id = resources.getIdentifier("companion_${type}_body", "drawable", packageName)
        if (id == 0) { stopSelf(); return }
        val opts = BitmapFactory.Options().apply { inScaled = false }
        val bitmap = BitmapFactory.decodeResource(resources, id, opts)   // the body, without the head
        if (bitmap == null) { stopSelf(); return }

        // the head on its own (cut along the real outline of the head)
        val headId = resources.getIdentifier("companion_${type}_head", "drawable", packageName)
        val head = if (headId != 0) BitmapFactory.decodeResource(resources, headId, opts) else null
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
