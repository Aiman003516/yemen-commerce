import Flutter
import Foundation
import Metal

final class EdgeRuntimeBridge {
  static let channelName = "com.yemencommerce/edge_runtime.v1"
  private static let unavailableCode = "MODEL_RUNTIME_NOT_ENABLED"
  private static let unavailableMessage = "محرك الذكاء المحلي غير متاح أو لم يتم تفعيله بعد."

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "status":
        result([
          "platform": "ios",
          "state": "unavailable",
          "backend": "rules_only_fallback",
          "supports_cancellation": false,
          "message_ar": unavailableMessage,
          "error_code": unavailableCode,
        ])
      case "capabilities":
        result(capabilityPayload())
      case "loadModel", "infer":
        result(FlutterError(
          code: unavailableCode,
          message: unavailableMessage,
          details: nil
        ))
      case "cancel":
        result(["cancelled": false])
      case "unloadModel":
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func capabilityPayload() -> [String: Any] {
    let memoryMb = Int(ProcessInfo.processInfo.physicalMemory / (1024 * 1024))
    return [
      "platform": "ios",
      "os_version": UIDevice.current.systemVersion,
      "device_model": UIDevice.current.model,
      "memory_mb": memoryMb,
      "supports_native_runtime": false,
      "supports_hardware_acceleration": MTLCreateSystemDefaultDevice() != nil,
      "is_low_power_mode": ProcessInfo.processInfo.isLowPowerModeEnabled,
      "is_metered_network": false,
    ]
  }
}
