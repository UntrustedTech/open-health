import ActivityKit
import Flutter
import Foundation

/// Starts, updates and ends the workout's Live Activity for Dart's
/// "health/live_activity" channel. Does nothing before iOS 16.2 or when
/// Live Activities are turned off.
enum WorkoutActivity {
  static func register(with messenger: FlutterBinaryMessenger) {
    FlutterMethodChannel(name: "health/live_activity", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        guard #available(iOS 16.2, *) else {
          result(false)
          return
        }
        let args = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "start":
          result(WorkoutActivity.start(args))
        case "update":
          WorkoutActivity.update(args)
          result(true)
        case "end":
          WorkoutActivity.end()
          result(true)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
  }

  @available(iOS 16.2, *)
  private static func state(_ args: [String: Any]) -> WorkoutAttributes.ContentState {
    let elapsed = (args["elapsed"] as? NSNumber)?.doubleValue ?? 0
    return WorkoutAttributes.ContentState(
      start: Date().addingTimeInterval(-elapsed),
      paused: args["paused"] as? Bool ?? false,
      elapsed: elapsed,
      detail: args["detail"] as? String ?? "")
  }

  @available(iOS 16.2, *)
  private static func start(_ args: [String: Any]) -> Bool {
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return false }
    end()
    let attributes = WorkoutAttributes(
      name: args["name"] as? String ?? "Workout",
      type: args["type"] as? String ?? "",
      color: (args["color"] as? NSNumber)?.intValue ?? 0xFF2EC7A5)
    do {
      _ = try Activity.request(
        attributes: attributes,
        content: ActivityContent(state: state(args), staleDate: nil))
      return true
    } catch {
      NSLog("WorkoutActivity: could not start: \(error)")
      return false
    }
  }

  @available(iOS 16.2, *)
  private static func update(_ args: [String: Any]) {
    let content = ActivityContent(state: state(args), staleDate: nil)
    for activity in Activity<WorkoutAttributes>.activities {
      Task { await activity.update(content) }
    }
  }

  @available(iOS 16.2, *)
  private static func end() {
    for activity in Activity<WorkoutAttributes>.activities {
      Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }
  }
}
