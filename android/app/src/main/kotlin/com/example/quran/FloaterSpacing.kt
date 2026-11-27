package com.example.quran

import android.content.Context
import android.graphics.Rect
import android.util.TypedValue
import kotlin.math.abs

/**
 * Keeps the two floaters (Tasbeeh and Companion) from sitting on top of each
 * other. When they overlap, BOTH glide apart by half the needed distance in
 * opposite directions (neither one pushes the other). If one is against the
 * screen edge, the other moves the rest of the way.
 *
 * When the Tasbeeh is above the Companion, the Companion's keep-clear zone also
 * covers the room its speech bubble needs above its head, so a bubble never
 * shows up under the Tasbeeh.
 *
 * Runs when either one is let go, turned on, or put back after a rotation;
 * never while one of them is being dragged.
 *
 * Both floaters are placed in the same area, so their positions (the window's
 * top-left) can be compared directly.
 */
internal object FloaterSpacing {

    /** One floater, as seen by this check. */
    interface Floater {
        /** Being dragged or gliding: leave it alone for now. */
        val busy: Boolean
        /** The visible part, in placement-area coordinates. */
        fun body(): Rect?
        /** How far its window's top-left may go (x/y min and max), so it stays on screen. */
        fun limits(): Rect
        /** Its window's top-left now. */
        fun position(): Pair<Int, Int>
        /** Glides its window's top-left to (x, y), then remembers the place. */
        fun glideTo(x: Int, y: Int)
    }

    private fun dp(context: Context, v: Float) =
        TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v, context.resources.displayMetrics).toInt()

    fun check(context: Context) {
        val companion = CompanionOverlayService.instance ?: return
        val tasbeeh = TasbeehOverlayService.instance ?: return
        if (companion.busy || tasbeeh.busy) return
        val c = companion.body() ?: return
        val t = tasbeeh.body() ?: return

        // the companion's keep-clear zone: its body, plus room for its speech
        // bubble above its head when the Tasbeeh is on top of it
        val zone = Rect(c)
        val tasbeehOnTop = t.centerY() < c.top + c.height() / 3
        if (tasbeehOnTop) {
            val bubbleW = dp(context, 240f)   // widest bubble (its text box is at most 240 dp)
            val bubbleH = dp(context, 80f)    // room for a bubble of up to three lines
            zone.union(Rect(c.centerX() - bubbleW / 2, c.top - bubbleH, c.centerX() + bubbleW / 2, c.top))
        }
        val gap = dp(context, 8f)
        val padded = Rect(zone).apply { inset(-gap, -gap) }
        if (!Rect.intersects(padded, t)) return

        // how far apart they must go along each axis (the Tasbeeh's way;
        // the companion goes the opposite way)
        val goRight = t.centerX() >= zone.centerX()
        val goDown = t.centerY() >= zone.centerY()
        val needX = if (goRight) padded.right - t.left else t.right - padded.left
        val needY = if (goDown) padded.bottom - t.top else t.bottom - padded.top
        // the shorter way apart
        val alongX = needX <= needY
        val need = if (alongX) needX else needY
        val sign = if (alongX) (if (goRight) 1 else -1) else (if (goDown) 1 else -1)

        val (tx0, ty0) = tasbeeh.position()
        val (cx0, cy0) = companion.position()
        val tl = tasbeeh.limits()
        val cl = companion.limits()

        fun clampMove(pos: Int, move: Int, min: Int, max: Int) = (pos + move).coerceIn(min, max) - pos

        // half each, in opposite directions
        val half = need / 2
        var tMove: Int
        var cMove: Int
        if (alongX) {
            tMove = clampMove(tx0, sign * (need - half), tl.left, tl.right)
            cMove = clampMove(cx0, -sign * half, cl.left, cl.right)
            // one hit the edge: the other covers the rest
            val left = need - abs(tMove) - abs(cMove)
            if (left > 0) {
                tMove += clampMove(tx0 + tMove, sign * left, tl.left, tl.right)
                val still = need - abs(tMove) - abs(cMove)
                if (still > 0) cMove += clampMove(cx0 + cMove, -sign * still, cl.left, cl.right)
            }
            tasbeeh.glideTo(tx0 + tMove, ty0)
            companion.glideTo(cx0 + cMove, cy0)
        } else {
            tMove = clampMove(ty0, sign * (need - half), tl.top, tl.bottom)
            cMove = clampMove(cy0, -sign * half, cl.top, cl.bottom)
            val left = need - abs(tMove) - abs(cMove)
            if (left > 0) {
                tMove += clampMove(ty0 + tMove, sign * left, tl.top, tl.bottom)
                val still = need - abs(tMove) - abs(cMove)
                if (still > 0) cMove += clampMove(cy0 + cMove, -sign * still, cl.top, cl.bottom)
            }
            tasbeeh.glideTo(tx0, ty0 + tMove)
            companion.glideTo(cx0, cy0 + cMove)
        }
    }
}
