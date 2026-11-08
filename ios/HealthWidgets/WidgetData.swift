import SwiftUI
import WidgetKit

/// The App Group the app and the widgets share (see `HomeWidgets` in Dart).
let appGroup = "group.health.untrustedtech.dev"

/// Reads the values the app saves for the widgets, as Android's
/// WidgetData.kt does: today's totals, goals and the app's colours.
struct WidgetData {
  let defaults = UserDefaults(suiteName: appGroup)
  let todayText = WidgetData.day.string(from: Date())

  static let day: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd"
    return f
  }()

  /// True while App Lock hides the widgets' data.
  var hidden: Bool { defaults?.bool(forKey: "hidden") ?? false }

  /// Values belong to "date"; after midnight the widgets show zeros.
  private var isToday: Bool { text("date") == todayText }

  func value(_ key: String) -> Int { (defaults?.object(forKey: key) as? NSNumber)?.intValue ?? 0 }

  func today(_ key: String) -> Int { isToday ? value(key) : 0 }

  func text(_ key: String) -> String? { defaults?.string(forKey: key) }

  func has(_ key: String) -> Bool { defaults?.object(forKey: key) != nil }

  /// Water has its own date: the widget's button adds to it without the app.
  var water: Int {
    let date = text("waterDate") ?? text("date")
    return date == todayText ? value("water") : 0
  }

  /// A this-week value, or 0 once the saved week has ended.
  func thisWeek(_ key: String) -> Int {
    guard let ends = text("weekEnds") else { return value(key) }
    // yyyy-MM-dd text sorts in date order.
    return todayText < ends ? value(key) : 0
  }

  func progress(_ key: String, goal: String) -> Double {
    let g = value(goal)
    return g <= 0 ? 0 : Double(today(key)) / Double(g)
  }

  var imperial: Bool { defaults?.bool(forKey: "imperial") ?? false }

  /// Water in the user's units: "1,250" ml or "42.3" fl oz.
  func waterAmount(_ ml: Int) -> String {
    imperial
      ? (Double(ml) / 29.5735295625).formatted(.number.precision(.fractionLength(1)))
      : ml.formatted()
  }

  /// "wMode": 0 follows the phone, 1 light, 2 dark.
  func dark(_ scheme: ColorScheme) -> Bool {
    switch value("wMode") {
    case 1: return false
    case 2: return true
    default: return scheme == .dark
    }
  }

  /// A colour the app saved (light or dark), or nil.
  func colour(_ light: String, _ night: String, dark: Bool) -> Color? {
    let key = dark ? night : light
    return has(key) ? Color(argb: value(key)) : nil
  }

  /// The widget's colours in the app's theme, with [fallback] as the
  /// accent when themed widgets are off.
  func theme(_ scheme: ColorScheme, fallback: Color) -> WidgetTheme {
    let d = dark(scheme)
    return WidgetTheme(
      background: colour("wBgL", "wBgD", dark: d)
        ?? (d ? Color(argb: 0xFF1C1C1E) : Color(argb: 0xFFFFFFFF)),
      label: colour("wLabelL", "wLabelD", dark: d) ?? (d ? .white : .black),
      secondary: colour("wSecL", "wSecD", dark: d)
        ?? (d ? Color(argb: 0x99EBEBF5) : Color(argb: 0x993C3C43)),
      accent: colour("wAccentL", "wAccentD", dark: d) ?? fallback,
      dark: d
    )
  }
}

struct WidgetTheme {
  let background: Color
  let label: Color
  let secondary: Color
  let accent: Color
  let dark: Bool

  var track: Color { label.opacity(0.14) }
  var wash: Color { accent.opacity(dark ? 0.22 : 0.14) }
}

extension Color {
  init(argb: Int) {
    self.init(
      .sRGB,
      red: Double((argb >> 16) & 0xFF) / 255,
      green: Double((argb >> 8) & 0xFF) / 255,
      blue: Double(argb & 0xFF) / 255,
      opacity: Double((argb >> 24) & 0xFF) / 255)
  }

  static let move = Color(argb: 0xFFFF4D7D)
  static let exercise = Color(argb: 0xFF2EE6C5)
  static let steps = Color(argb: 0xFF8B9CFF)
  static let water = Color(argb: 0xFF2FA8E6)
  static let green = Color(argb: 0xFF2EC7A5)
  static let fasting = Color(argb: 0xFF8C7BFF)
}

/// A link the app opens; "homeWidget" marks it as a widget tap for the
/// home_widget plugin.
func appLink(_ path: String) -> URL {
  var c = URLComponents(string: "health://\(path)")!
  c.queryItems = (c.queryItems ?? []) + [URLQueryItem(name: "homeWidget", value: nil)]
  return c.url!
}

/// One timeline entry: widgets reread the saved values when drawn, and
/// redraw after midnight so yesterday's totals turn to zero.
struct DayEntry: TimelineEntry {
  let date: Date
}

struct DayProvider: TimelineProvider {
  func placeholder(in context: Context) -> DayEntry { DayEntry(date: Date()) }

  func getSnapshot(in context: Context, completion: @escaping (DayEntry) -> Void) {
    completion(DayEntry(date: Date()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<DayEntry>) -> Void) {
    let midnight = Calendar.current.startOfDay(for: Date()).addingTimeInterval(86_400)
    completion(Timeline(entries: [DayEntry(date: Date())], policy: .after(midnight)))
  }
}

/// The widget's header: icon and title in the accent colour.
struct WidgetHeader: View {
  let icon: String
  let title: String
  let theme: WidgetTheme

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: icon).font(.caption.weight(.semibold))
      Text(title).font(.caption.weight(.semibold)).lineLimit(1)
    }
    .foregroundStyle(theme.accent)
    .accessibilityElement(children: .combine)
  }
}

/// A rounded progress capsule.
struct ProgressCapsule: View {
  let value: Double
  let theme: WidgetTheme

  var body: some View {
    GeometryReader { geo in
      ZStack(alignment: .leading) {
        Capsule().fill(theme.track)
        Capsule().fill(theme.accent)
          .frame(width: geo.size.width * min(max(value, 0), 1))
      }
    }
    .frame(height: 6)
    .accessibilityHidden(true)
  }
}

/// Shown instead of the data while App Lock hides it.
struct LockedView: View {
  let theme: WidgetTheme

  var body: some View {
    VStack(spacing: 6) {
      Image(systemName: "lock.fill").font(.title2)
      Text("Locked").font(.footnote.weight(.semibold))
    }
    .foregroundStyle(theme.secondary)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .accessibilityElement(children: .combine)
  }
}

/// Puts the theme's background behind a widget, and the lock over it when
/// hidden.
struct ThemedWidget<Content: View>: View {
  @Environment(\.colorScheme) var scheme
  let fallback: Color
  let link: String
  @ViewBuilder let content: (WidgetData, WidgetTheme) -> Content

  var body: some View {
    let data = WidgetData()
    let theme = data.theme(scheme, fallback: fallback)
    Group {
      if data.hidden {
        LockedView(theme: theme)
      } else {
        content(data, theme)
      }
    }
    .containerBackground(theme.background, for: .widget)
    .widgetURL(appLink(link))
  }
}
