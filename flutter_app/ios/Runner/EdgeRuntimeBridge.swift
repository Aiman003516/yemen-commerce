import Flutter
import Foundation

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
}
