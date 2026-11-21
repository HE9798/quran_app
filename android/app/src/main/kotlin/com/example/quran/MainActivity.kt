package com.example.quran

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {

    private fun startOverlay() {
        val intent = Intent(this, TasbeehOverlayService::class.java)
        if (Build.VERSION.SDK_INT >= 26) startForegroundService(intent) else startService(intent)
    }

    private fun startCompanion() {
        val intent = Intent(this, CompanionOverlayService::class.java)
        if (Build.VERSION.SDK_INT >= 26) startForegroundService(intent) else startService(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ---- companion mode
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "werd/companion")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "state" -> result.success(
                        mapOf(
                            "permission" to Settings.canDrawOverlays(this),
                            "enabled" to CompanionStore.enabled(this),
                            "type" to CompanionStore.type(this)
                        )
                    )
                    // start (or restart with another companion): arg = "sheikh" / "sister"
                    "start" -> {
                        if (Settings.canDrawOverlays(this)) {
                            CompanionStore.setType(this, (call.arguments as? String) ?: "sheikh")
                            CompanionStore.setEnabled(this, true)
                            stopService(Intent(this, CompanionOverlayService::class.java))
                            startCompanion()
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    }
                    "stop" -> {
                        CompanionStore.setEnabled(this, false)
                        stopService(Intent(this, CompanionOverlayService::class.java))
                        result.success(null)
                    }
                    "restore" -> {
                        if (CompanionStore.enabled(this) && Settings.canDrawOverlays(this)) startCompanion()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "werd/tasbeeh_widget")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "overlayState" -> result.success(
                        mapOf(
                            "permission" to Settings.canDrawOverlays(this),
                            "enabled" to TasbeehStore.overlayEnabled(this)
                        )
                    )
                    // opens the phone's "Display over other apps" page for this app
                    "overlayPermission" -> {
                        startActivity(
                            Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName"))
                        )
                        result.success(null)
                    }
                    "overlayStart" -> {
                        if (Settings.canDrawOverlays(this)) {
                            TasbeehStore.setOverlayEnabled(this, true)
                            startOverlay()
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    }
                    "overlayStop" -> {
                        TasbeehStore.setOverlayEnabled(this, false)
                        stopService(Intent(this, TasbeehOverlayService::class.java))
                        result.success(null)
                    }
                    // called when the app opens: bring the button back if it was on
                    "overlayRestore" -> {
                        if (TasbeehStore.overlayEnabled(this) && Settings.canDrawOverlays(this)) {
                            startOverlay()
                        }
                        result.success(null)
                    }
                    "reset" -> {
                        TasbeehStore.reset(this)
                        result.success(null)
                    }
                    "state" -> result.success(
                        mapOf(
                            "count" to TasbeehStore.count(this),
                            "combo" to TasbeehStore.combo(this),
                            "target" to TasbeehStore.target(this)
                        )
                    )
                    "getTarget" -> result.success(TasbeehStore.target(this))
                    "setTarget" -> {
                        TasbeehStore.setTarget(this, (call.arguments as? Int) ?: 100)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
