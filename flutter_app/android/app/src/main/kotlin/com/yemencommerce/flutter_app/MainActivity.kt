package com.yemencommerce.flutter_app

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.yemencommerce/edge_runtime.v1"
    private val unavailableCode = "MODEL_RUNTIME_NOT_ENABLED"
    private val unavailableMessage = "محرك الذكاء المحلي غير متاح أو لم يتم تفعيله بعد."

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
                when (call.method) {
                    "status" -> result.success(statusPayload())
                    "capabilities" -> result.success(capabilityPayload())
                    "loadModel", "infer" -> result.error(
                        unavailableCode,
                        unavailableMessage,
                        null,
                    )
                    "cancel" -> result.success(mapOf("cancelled" to false))
                    "unloadModel" -> result.success(null)
                    else -> result.notImplemented()
                }
            }
    }

    private fun capabilityPayload(): Map<String, Any> {
        val memoryInfo = ActivityManager.MemoryInfo()
        val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        activityManager.getMemoryInfo(memoryInfo)
        return mapOf(
            "platform" to "android",
            "os_version" to Build.VERSION.RELEASE,
            "device_model" to Build.MODEL,
            "memory_mb" to (memoryInfo.totalMem / (1024 * 1024)).toInt(),
            "supports_native_runtime" to false,
            "supports_hardware_acceleration" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP),
            "is_low_power_mode" to false,
            "is_metered_network" to false,
        )
    }

    private fun statusPayload(): Map<String, Any> = mapOf(
        "platform" to "android",
        "state" to "unavailable",
        "backend" to "rules_only_fallback",
        "supports_cancellation" to false,
        "message_ar" to unavailableMessage,
        "error_code" to unavailableCode,
    )
}
