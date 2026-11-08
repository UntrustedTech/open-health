import ActivityKit
import Foundation

/// The workout on the Lock Screen and in the Dynamic Island. Shared by the
/// app (which starts and updates it) and the widget extension (which draws
/// it), so both must agree on these fields.
@available(iOS 16.1, *)
struct WorkoutAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    /// When the clock would have started had it never paused, so the
    /// system can count up by itself while the app sleeps.
    var start: Date
    var paused: Bool
    /// Seconds recorded, shown while paused.
    var elapsed: Double
    /// e.g. "2.31 km", or empty.
    var detail: String
  }

  var name: String
  /// The app's workout type name, e.g. "run".
  var type: String
  /// 0xAARRGGBB.
  var color: Int
}
