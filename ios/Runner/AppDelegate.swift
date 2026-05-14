import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let apiKey = googleMapsApiKey()
    if !apiKey.isEmpty {
      GMSServices.provideAPIKey(apiKey)
    }
    GeneratedPluginRegistrant.register(with: self)
    configureEnvironmentChannel()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func configureEnvironmentChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }

    let channel = FlutterMethodChannel(
      name: "sakaynow_buenatoda/environment",
      binaryMessenger: controller.binaryMessenger
    )

    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "googleServicesApiKey":
        result(self?.googleMapsApiKey() ?? "")
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func googleMapsApiKey() -> String {
    guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "GoogleMapsApiKey") as? String else {
      return ""
    }

    let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmedKey.isEmpty || trimmedKey.contains("$(") {
      return ""
    }

    return trimmedKey
  }
}
