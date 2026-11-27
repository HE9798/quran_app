package com.example.quran

import android.content.Context
import android.os.Build
import android.view.WindowInsets
import android.view.WindowManager

/**
 * The area the floating windows (Tasbeeh, Companion) are placed in: the screen
 * minus the status bar, the navigation bar and the camera cut-out. A floating
 * window's x / y are measured from this area's top-left corner, so this, not the
 * full screen size, is what keeps them inside the screen.
 *
 * Measured on the phone: upright 1080 x 2230 (screen 1080 x 2412), sideways
 * 2286 x 940 (screen 2412 x 1080; the cut-out and the bars move to the sides).
 */
internal object OverlayArea {
    class Size(val widthPixels: Int, val heightPixels: Int)

    fun of(context: Context): Size {
        if (Build.VERSION.SDK_INT >= 30) {
            runCatching {
                val metrics = context.getSystemService(WindowManager::class.java).currentWindowMetrics
                val insets = metrics.windowInsets.getInsetsIgnoringVisibility(
                    WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout()
                )
                val w = metrics.bounds.width() - insets.left - insets.right
                val h = metrics.bounds.height() - insets.top - insets.bottom
                if (w > 0 && h > 0) return Size(w, h)
            }
        }
        val dm = context.resources.displayMetrics
        return Size(dm.widthPixels, dm.heightPixels)
    }
}
