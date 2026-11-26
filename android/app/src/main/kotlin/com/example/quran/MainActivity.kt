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
                            "type" to CompanionStore.type(this),
                            "bubbles" to CompanionStore.bubbles(this)
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
                    "say" -> {
                        val a = call.arguments as? Map<*, *>
                        val text = a?.get("text") as? String
                        val ms = (a?.get("ms") as? Number)?.toLong() ?: 5000L
                        if (text != null) CompanionOverlayService.instance?.say(text, ms)
                        result.success(null)
                    }
                    // list of {id, at (ms since 1970), text}
                    "scheduleBubbles" -> {
                        val list = (call.arguments as? List<*>) ?: emptyList<Any>()
                        val events = list.mapNotNull { e ->
                            val x = e as? Map<*, *> ?: return@mapNotNull null
                            val id = (x["id"] as? Number)?.toInt() ?: return@mapNotNull null
                            val at = (x["at"] as? Number)?.toLong() ?: return@mapNotNull null
                            val text = x["text"] as? String ?: return@mapNotNull null
                            Triple(id, at, text)
                        }
                        CompanionAlarms.replaceAll(this, events)
                        result.success(null)
                    }
                    // the pictures, sent by the app from its assets: name -> png bytes
                    "syncImages" -> {
                        val images = mutableMapOf<String, ByteArray>()
                        (call.arguments as? Map<*, *>)?.forEach { (k, v) ->
                            if (k is String && v is ByteArray) images[k] = v
                        }
                        result.success(CompanionStore.saveImages(this, images))
                    }
                    "claimPending" -> result.success(CompanionStore.claimPending(this))
                    "setStrings" -> {
                        (call.arguments as? Map<*, *>)?.forEach { (k, v) ->
                            if (k is String && v is String) CompanionStore.setString(this, k, v)
                        }
                        result.success(null)
                    }
                    // the companion full screen over the lock screen
                    "lockState" -> result.success(
                        mapOf(
                            "enabled" to CompanionStore.lockScreen(this),
                            "allowed" to CompanionLockScreen.allowed(this)
                        )
                    )
                    "setLockScreen" -> {
                        CompanionStore.setLockScreen(this, (call.arguments as? Boolean) ?: true)
                        result.success(null)
                    }
                    // Android 14+: the page where full-screen notifications are allowed
                    "lockPermission" -> {
                        if (Build.VERSION.SDK_INT >= 34) {
                            runCatching {
                                startActivity(Intent(
                                    Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT,
                                    Uri.parse("package:$packageName")
                                ))
                            }
                        }
                        result.success(null)
                    }
                    "setBubbles" -> {
                        CompanionStore.setBubbles(this, (call.arguments as? Boolean) ?: true)
                        result.success(null)
                    }
                    "stop" -> {
                        CompanionStore.setEnabled(this, false)
                        stopService(Intent(this, CompanionOverlayService::class.java))
                        result.success(null)
                    }
                    // arg true = the pictures changed: show the new ones
                    "restore" -> {
                        if (CompanionStore.enabled(this) && Settings.canDrawOverlays(this)) {
                            if (call.arguments == true) {
                                stopService(Intent(this, CompanionOverlayService::class.java))
                            }
                            startCompanion()
                        }
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
