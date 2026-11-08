import Flutter
import HealthKit
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// "Hide in App Switcher": set from Dart through "health/secure".
  private var hideInSwitcher = false
  private var cover: UIView?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // While the app isn't active (and when the app switcher takes its
    // snapshot) a blur covers it, so no health data shows there. These
    // notifications leave Flutter's own scene handling untouched.
    let center = NotificationCenter.default
    center.addObserver(
      self, selector: #selector(sceneWillDeactivate(_:)),
      name: UIScene.willDeactivateNotification, object: nil)
    center.addObserver(
      self, selector: #selector(sceneDidActivate(_:)),
      name: UIScene.didActivateNotification, object: nil)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // Reminders that fire while the app is open still show (see
    // flutter_local_notifications' iOS setup).
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "HealthScreens")
    else { return }
    // Apple Health has no link to an app's permissions, and they aren't in
    // the app's Settings page: both open the Health app, where they're under
    // the profile picture › Apps.
    FlutterMethodChannel(name: "health/connect", binaryMessenger: registrar.messenger())
      .setMethodCallHandler { call, result in
        let target: String
        switch call.method {
        case "openPermissions", "openData": target = "x-apple-health://"
        case "authStatus":
          Self.healthAuthStatus(result)
          return
        default:
          result(FlutterMethodNotImplemented)
          return
        }
        guard let url = URL(string: target) else {
          result(false)
          return
        }
        UIApplication.shared.open(url) { opened in result(opened) }
      }
    // The Home Screen icon (Appearance → App Icon): "Default", or the name
    // of an AppIcon-<Name> set in Assets.xcassets. iOS confirms the change
    // with its own alert.
    FlutterMethodChannel(name: "health/icon", binaryMessenger: registrar.messenger())
      .setMethodCallHandler { call, result in
        let app = UIApplication.shared
        switch call.method {
        case "current":
          result(app.alternateIconName.map { String($0.dropFirst("AppIcon-".count)) } ?? "Default")
        case "set":
          guard let name = call.arguments as? String, app.supportsAlternateIcons else {
            result(false)
            return
          }
          let icon = name == "Default" ? nil : "AppIcon-\(name)"
          guard icon != app.alternateIconName else {
            result(true)
            return
          }
          app.setAlternateIconName(icon) { error in
            DispatchQueue.main.async { result(error == nil) }
          }
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    WorkoutActivity.register(with: registrar.messenger())
    FlutterMethodChannel(name: "health/secure", binaryMessenger: registrar.messenger())
      .setMethodCallHandler { [weak self] call, result in
        guard call.method == "setSecure" else {
          result(FlutterMethodNotImplemented)
          return
        }
        self?.hideInSwitcher = call.arguments as? Bool ?? false
        if self?.hideInSwitcher == false { self?.removeCover() }
        result(nil)
      }
  }

  /// Whether Apple Health has yet to ask the user ("shouldRequest"): it
  /// asks only once, and refused reads look like no data. Step count stands
  /// in for every type, as they're all asked for together. Fails with
  /// HealthKit's reason when the app can't use it, e.g. when it was signed
  /// without the HealthKit entitlement.
  private static func healthAuthStatus(_ result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable(),
      let steps = HKObjectType.quantityType(forIdentifier: .stepCount)
    else {
      result("unavailable")
      return
    }
    HKHealthStore().getRequestStatusForAuthorization(toShare: [], read: [steps]) {
      status, error in
      DispatchQueue.main.async {
        if let error = error {
          result(
            FlutterError(code: "healthkit", message: error.localizedDescription, details: nil))
          return
        }
        switch status {
        case .shouldRequest: result("shouldRequest")
        case .unnecessary: result("unnecessary")
        default: result("unknown")
        }
      }
    }
  }

  @objc private func sceneWillDeactivate(_ note: Notification) {
    guard hideInSwitcher, cover == nil,
      let scene = note.object as? UIWindowScene,
      let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first
    else { return }
    let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemThickMaterial))
    blur.frame = window.bounds
    blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    window.addSubview(blur)
    cover = blur
  }

  @objc private func sceneDidActivate(_ note: Notification) {
    removeCover()
  }

  private func removeCover() {
    cover?.removeFromSuperview()
    cover = nil
  }
}
