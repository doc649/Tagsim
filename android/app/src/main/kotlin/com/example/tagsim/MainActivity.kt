package com.example.tagsim

import android.content.Context
import android.os.Build
import android.telephony.TelephonyManager
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.tagsim/telephony"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            if (call.method == "isRoaming") {
                try {
                    val isRoaming = isNetworkRoaming()
                    result.success(isRoaming)
                } catch (e: Exception) {
                    result.error("ROAMING_CHECK_FAILED", "Failed to check roaming status.", e.toString())
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun isNetworkRoaming(): Boolean {
        val telephonyManager = context.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
        // Note: Requires READ_PHONE_STATE permission for API levels < 29
        // For API 29+, READ_PHONE_STATE is needed only if the app targets API 29+ and runs on Android 10+
        // Let's assume the permission will be handled.
        return telephonyManager.isNetworkRoaming
    }
}

