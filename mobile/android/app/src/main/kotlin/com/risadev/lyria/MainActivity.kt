package com.risadev.lyria

import android.content.ActivityNotFoundException
import android.content.Intent
import android.media.MediaRouter2
import android.os.Build
import android.provider.Settings
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "showRoutePicker" -> result.success(showRoutePicker())
                    else -> result.notImplemented()
                }
            }
    }

    private fun showRoutePicker(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val shown = MediaRouter2.getInstance(this).showSystemOutputSwitcher()
            if (shown) return true
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            if (tryStart(Intent(MEDIA_OUTPUT_PANEL_ACTION))) return true
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            if (tryStart(Intent(Settings.Panel.ACTION_VOLUME))) return true
        }

        return tryStart(Intent(Settings.ACTION_BLUETOOTH_SETTINGS)) ||
            tryStart(Intent(Settings.ACTION_SOUND_SETTINGS))
    }

    private fun tryStart(intent: Intent): Boolean {
        return try {
            startActivity(intent)
            true
        } catch (_: ActivityNotFoundException) {
            false
        }
    }

    companion object {
        private const val CHANNEL = "lyria/audio_routes"
        private const val MEDIA_OUTPUT_PANEL_ACTION = "com.android.settings.panel.action.MEDIA_OUTPUT"
    }
}
