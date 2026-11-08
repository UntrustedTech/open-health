import AppIntents
import SwiftUI
import WidgetKit

/// The Home Screen widgets and the workout Live Activity. They match the
/// Android ones and read what the app saves in the shared App Group.
@main
struct HealthWidgets: WidgetBundle {
  var body: some Widget {
    ActivityWidget()
    WaterWidget()
    WorkoutWidget()
    FastingWidget()
    ProgressWidget()
    WorkoutLiveActivity()
  }
}

// MARK: Activity

/// Today's Move, Exercise and Steps rings.
struct ActivityWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "ActivityWidget", provider: DayProvider()) { _ in
      ThemedWidget(fallback: .move, link: "summary") { data, theme in
        ActivityView(data: data, theme: theme)
      }
    }
    .configurationDisplayName("Activity")
    .description("Today's Move, Exercise and Steps.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

struct ActivityView: View {
  @Environment(\.widgetFamily) private var family
  let data: WidgetData
  let theme: WidgetTheme

  var body: some View {
    let rings = Rings(
      values: [
        data.progress("move", goal: "moveGoal"),
        data.progress("exercise", goal: "exerciseGoal"),
        data.progress("steps", goal: "stepsGoal"),
      ],
      theme: theme)
    let rows = VStack(alignment: .leading, spacing: 4) {
      row("Move", "\(data.today("move").formatted())/\(data.value("moveGoal").formatted()) Cal", .move)
      row("Exercise", "\(data.today("exercise"))/\(data.value("exerciseGoal")) min", .exercise)
      row("Steps", data.today("steps").formatted(), .steps)
    }
    if family == .systemSmall {
      VStack(alignment: .leading, spacing: 8) {
        rings.frame(width: 64, height: 64)
        rows.font(.caption2.weight(.semibold))
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    } else {
      HStack(spacing: 16) {
        rings.frame(width: 110, height: 110)
        rows.font(.subheadline.weight(.semibold))
        Spacer(minLength: 0)
      }
    }
  }

  private func row(_ name: String, _ value: String, _ colour: Color) -> some View {
    Text(value)
      .foregroundStyle(colour)
      .lineLimit(1)
      .minimumScaleFactor(0.7)
      .accessibilityLabel("\(name): \(value)")
  }
}

/// Apple-style rings, outermost first, each in its own colour.
struct Rings: View {
  let values: [Double]
  let theme: WidgetTheme
  private let colours: [Color] = [.move, .exercise, .steps]

  var body: some View {
    GeometryReader { geo in
      let side = min(geo.size.width, geo.size.height)
      let width = side * 0.12
      ZStack {
        ForEach(values.indices, id: \.self) { i in
          let inset = CGFloat(i) * (width + 2) + width / 2
          ZStack {
            Circle().stroke(colours[i].opacity(0.2), lineWidth: width)
            Circle()
              .trim(from: 0, to: min(max(values[i], 0), 1))
              .stroke(colours[i], style: StrokeStyle(lineWidth: width, lineCap: .round))
              .rotationEffect(.degrees(-90))
          }
          .padding(inset)
        }
      }
      .frame(width: side, height: side)
    }
    .accessibilityHidden(true)
  }
}

// MARK: Water

/// Today's water with a one-tap "+250 ml" button.
struct WaterWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "WaterWidget", provider: DayProvider()) { _ in
      ThemedWidget(fallback: .water, link: "summary") { data, theme in
        WaterView(data: data, theme: theme)
      }
    }
    .configurationDisplayName("Water")
    .description("Today's water, with a button to add a glass.")
    .supportedFamilies([.systemSmall])
  }
}

struct WaterView: View {
  let data: WidgetData
  let theme: WidgetTheme

  var body: some View {
    let water = data.water
    let goal = max(data.value("waterGoal"), 1)
    let button = (data.text("waterButton") ?? "+ 250 ml")
      .replacingOccurrences(of: "+", with: "").trimmingCharacters(in: .whitespaces)
    VStack(alignment: .leading, spacing: 4) {
      WidgetHeader(icon: "drop.fill", title: "Water", theme: theme)
      Spacer(minLength: 0)
      Text(data.waterAmount(water))
        .font(.title.weight(.bold)).monospacedDigit()
        .foregroundStyle(theme.label)
        .minimumScaleFactor(0.6).lineLimit(1)
      Text(data.text("waterGoalText") ?? "of \(goal.formatted()) ml")
        .font(.caption).foregroundStyle(theme.secondary).lineLimit(1)
      ProgressCapsule(value: Double(water) / Double(goal), theme: theme)
      Button(intent: AddWaterIntent()) {
        Label(button, systemImage: "plus")
          .font(.caption.weight(.semibold))
          .frame(maxWidth: .infinity, minHeight: 32)
      }
      .buttonStyle(.plain)
      .foregroundStyle(theme.accent)
      .background(theme.wash, in: Capsule())
      .accessibilityLabel("Add \(button) of water")
    }
  }
}

/// Adds a glass without opening the app. Like Android's background
/// callback, it only queues the amount in "pendingWater" (the app adds it
/// to the encrypted store when it next opens) and bumps the shown total.
struct AddWaterIntent: AppIntent {
  static var title: LocalizedStringResource = "Add Water"
  static var isDiscoverable = false

  static let stepMl = 250

  func perform() async throws -> some IntentResult {
    guard let defaults = UserDefaults(suiteName: appGroup),
      !defaults.bool(forKey: "hidden")
    else { return .result() }
    let now = Int(Date().timeIntervalSince1970 * 1000)
    let item = "\(now):\(Self.stepMl)"
    let raw = defaults.string(forKey: "pendingWater") ?? ""
    defaults.set(raw.isEmpty ? item : "\(raw),\(item)", forKey: "pendingWater")
    // After midnight the saved total belongs to yesterday: start from zero.
    let today = WidgetData.day.string(from: Date())
    let waterDate = defaults.string(forKey: "waterDate") ?? defaults.string(forKey: "date")
    let shown = waterDate == today ? defaults.integer(forKey: "water") : 0
    defaults.set(shown + Self.stepMl, forKey: "water")
    defaults.set(today, forKey: "waterDate")
    return .result()
  }
}

// MARK: Workout

/// This week's workout minutes with quick-start buttons.
struct WorkoutWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "WorkoutWidget", provider: DayProvider()) { _ in
      ThemedWidget(fallback: .green, link: "fitness") { data, theme in
        WorkoutView(data: data, theme: theme)
      }
    }
    .configurationDisplayName("This Week")
    .description("Workout minutes this week, and a quick start.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

struct WorkoutView: View {
  @Environment(\.widgetFamily) private var family
  let data: WidgetData
  let theme: WidgetTheme

  var body: some View {
    let minutes = data.thisWeek("weekMinutes")
    // Zero means the user turned the weekly goal off.
    let rawGoal = data.value("weekGoal")
    let streak = data.value("streak")
    let count = data.thisWeek("weekCount")
    VStack(alignment: .leading, spacing: 4) {
      WidgetHeader(icon: "figure.run", title: "This Week", theme: theme)
      Spacer(minLength: 0)
      Text(rawGoal > 0 ? "\(minutes)/\(rawGoal) min" : "\(minutes) min")
        .font(.title2.weight(.bold)).monospacedDigit()
        .foregroundStyle(theme.label)
        .minimumScaleFactor(0.6).lineLimit(1)
      Text("\(count) workouts" + (streak > 1 ? " · \(streak)-day streak" : ""))
        .font(.caption).foregroundStyle(theme.secondary).lineLimit(1)
      if rawGoal > 0 {
        ProgressCapsule(value: Double(minutes) / Double(rawGoal), theme: theme)
      }
      if family != .systemSmall {
        HStack(spacing: 8) {
          start("Run", "figure.run", type: "run")
          start("Strength", "dumbbell.fill", type: "strength")
        }
      }
    }
  }

  private func start(_ title: String, _ icon: String, type: String) -> some View {
    Link(destination: appLink("workout/start?type=\(type)")) {
      Label(title, systemImage: icon)
        .font(.caption.weight(.semibold))
        .frame(maxWidth: .infinity, minHeight: 32)
        .foregroundStyle(theme.accent)
        .background(theme.wash, in: Capsule())
    }
    .accessibilityLabel(type == "run" ? "Start a run" : "Start strength training")
  }
}

// MARK: Fasting

struct FastingEntry: TimelineEntry {
  let date: Date
}

/// Redraws when the fast reaches its goal, to show it.
struct FastingProvider: TimelineProvider {
  func placeholder(in context: Context) -> FastingEntry { FastingEntry(date: Date()) }

  func getSnapshot(in context: Context, completion: @escaping (FastingEntry) -> Void) {
    completion(FastingEntry(date: Date()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<FastingEntry>) -> Void) {
    let data = WidgetData()
    var entries = [FastingEntry(date: Date())]
    if let start = data.fastStart {
      let goal = start.addingTimeInterval(Double(data.fastGoalMinutes) * 60)
      if goal > Date() { entries.append(FastingEntry(date: goal)) }
    }
    completion(Timeline(entries: entries, policy: .never))
  }
}

extension WidgetData {
  /// The running fast's start, or nil when not fasting.
  var fastStart: Date? {
    let ms = value("fastStart")
    let date = Date(timeIntervalSince1970: Double(ms) / 1000)
    return ms > 0 && date <= Date() ? date : nil
  }

  var fastGoalMinutes: Int { max(value("fastGoalMin"), 1) }
}

/// The fasting timer: counts up live, with time to the goal.
struct FastingWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "FastingWidget", provider: FastingProvider()) { entry in
      ThemedWidget(fallback: .fasting, link: "fasting") { data, theme in
        FastingView(now: entry.date, data: data, theme: theme)
      }
    }
    .configurationDisplayName("Fasting")
    .description("Your fast, counting up.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

struct FastingView: View {
  let now: Date
  let data: WidgetData
  let theme: WidgetTheme

  var body: some View {
    let goalMin = data.fastGoalMinutes
    let label = data.text("fastLabel") ?? "16:8"
    VStack(alignment: .leading, spacing: 4) {
      WidgetHeader(icon: "hourglass", title: "Fasting · \(label)", theme: theme)
      Spacer(minLength: 0)
      if let start = data.fastStart {
        let end = start.addingTimeInterval(Double(goalMin) * 60)
        Text(start, style: .timer)
          .font(.title.weight(.bold)).monospacedDigit()
          .foregroundStyle(theme.label)
          .minimumScaleFactor(0.6).lineLimit(1)
        Text(now >= end ? "Goal reached · \(hours(goalMin))" : "Ends \(end.formatted(date: .omitted, time: .shortened))")
          .font(.caption).foregroundStyle(theme.secondary).lineLimit(1)
        ProgressView(timerInterval: start...end, countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
          .tint(theme.accent)
          .accessibilityHidden(true)
      } else {
        Text("Not fasting")
          .font(.title3.weight(.bold))
          .foregroundStyle(theme.label)
        Text(goalMin % 60 == 0 ? "Tap to start a \(goalMin / 60)-hour fast" : "Tap to start a \(hours(goalMin)) fast")
          .font(.caption).foregroundStyle(theme.secondary).lineLimit(2)
      }
    }
  }

  /// "16 h", or "13 h 30 min" for a goal that isn't whole hours.
  private func hours(_ minutes: Int) -> String {
    minutes % 60 == 0 ? "\(minutes / 60) h" : "\(minutes / 60) h \(minutes % 60) min"
  }
}

// MARK: Progress

/// Workouts, this month and the weekly streak over a 16-week heatmap.
struct ProgressWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "ProgressWidget", provider: DayProvider()) { _ in
      ThemedWidget(fallback: .green, link: "stats") { data, theme in
        ProgressWidgetView(data: data, theme: theme)
      }
    }
    .configurationDisplayName("Progress")
    .description("Your workouts over the last 16 weeks.")
    .supportedFamilies([.systemMedium])
  }
}

struct ProgressWidgetView: View {
  let data: WidgetData
  let theme: WidgetTheme

  var body: some View {
    // One digit (0–4) per day, oldest first, in Monday–Sunday weeks;
    // days after today are "-".
    let heat = Array(data.text("progHeat") ?? "")
    let weeks = heat.count / 7
    HStack(spacing: 14) {
      VStack(alignment: .leading, spacing: 6) {
        WidgetHeader(icon: "chart.bar.fill", title: "Progress", theme: theme)
        Spacer(minLength: 0)
        stat(data.value("progWorkouts"), "Workouts")
        stat(data.value("progMonth"), "This month")
        stat(data.value("progStreak"), "Week streak")
      }
      Grid(horizontalSpacing: 2, verticalSpacing: 2) {
        ForEach(0..<7, id: \.self) { day in
          GridRow {
            ForEach(0..<weeks, id: \.self) { week in
              let c = heat[week * 7 + day]
              RoundedRectangle(cornerRadius: 2)
                .fill(cell(c))
                .aspectRatio(1, contentMode: .fit)
            }
          }
        }
      }
      .accessibilityHidden(true)
    }
  }

  private func cell(_ c: Character) -> Color {
    guard let level = c.wholeNumberValue else { return .clear }
    return level == 0 ? theme.track : theme.accent.opacity(0.25 + 0.1875 * Double(level))
  }

  private func stat(_ value: Int, _ label: String) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(value.formatted()).font(.headline.weight(.bold)).foregroundStyle(theme.label)
      Text(label).font(.caption2).foregroundStyle(theme.secondary)
    }
    .accessibilityElement(children: .combine)
  }
}
