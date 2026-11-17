package com.pawlypaint.pawlypaint

import android.os.Build
import android.view.Display
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.math.abs

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // PAP-59: play screens ask for 60 Hz (lib/state/display_rate.dart).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pawlypaint/display_rate")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "cap60" -> { setRefresh(60f); result.success(null) }
                    "release" -> { setRefresh(null); result.success(null) }
                    else -> result.notImplemented()
                }
            }
    }

    /** Pins the display mode with the current resolution and the refresh rate
     *  closest to [hz], or gives the choice back to the system when null. */
    private fun setRefresh(hz: Float?) {
        val attrs = window.attributes
        if (hz == null) {
            attrs.preferredDisplayModeId = 0
            attrs.preferredRefreshRate = 0f
        } else {
            val display: Display? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) display else {
                @Suppress("DEPRECATION")
                windowManager.defaultDisplay
            }
            val current = display?.mode
            val mode = display?.supportedModes
                ?.filter { current == null || (it.physicalWidth == current.physicalWidth && it.physicalHeight == current.physicalHeight) }
                ?.minByOrNull { abs(it.refreshRate - hz) }
            attrs.preferredDisplayModeId = mode?.modeId ?: 0
            attrs.preferredRefreshRate = hz
        }
        // The preferred mode is only a base: touches still boost the display to
        // its peak rate (seen on a Galaxy A56), which is exactly the drag we
        // want to slow. Android 15+ lets the window opt out of that boost.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM) {
            attrs.setFrameRateBoostOnTouchEnabled(hz == null)
        }
        window.attributes = attrs
    }
}
