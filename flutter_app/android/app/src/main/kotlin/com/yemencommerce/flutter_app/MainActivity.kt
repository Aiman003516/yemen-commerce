package com.yemencommerce.flutter_app

import android.os.Bundle
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

    private fun statusPayload(): Map<String, Any> = mapOf(
        "platform" to "android",
        "state" to "unavailable",
        "backend" to "rules_only_fallback",
        "supports_cancellation" to false,
        "message_ar" to unavailableMessage,
        "error_code" to unavailableCode,
    )
}
