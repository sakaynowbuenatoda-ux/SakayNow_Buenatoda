package com.example.sakaynow_buenatoda

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "sakaynow_buenatoda/environment"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "googleServicesApiKey" -> result.success(readGoogleMapsApiKey())
                else -> result.notImplemented()
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun readGoogleMapsApiKey(): String {
        return try {
            val applicationInfo = packageManager.getApplicationInfo(
                packageName,
                PackageManager.GET_META_DATA
            )
            applicationInfo.metaData
                ?.getString("com.google.android.geo.API_KEY")
                ?.trim()
                .orEmpty()
        } catch (_: Exception) {
            ""
        }
    }
}
