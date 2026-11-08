import ActivityKit
import SwiftUI
import WidgetKit

/// The workout being recorded, on the Lock Screen and in the Dynamic
/// Island. The clock counts by itself; the app updates it on pause, resume
/// and new distance.
struct WorkoutLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: WorkoutAttributes.self) { context in
      LockScreenWorkout(context: context)
        .padding(16)
        .activityBackgroundTint(Color.black.opacity(0.6))
        .activitySystemActionForegroundColor(.white)
        .widgetURL(appLink("workout"))
    } dynamicIsland: { context in
      let colour = Color(argb: context.attributes.color)
      return DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Label(context.attributes.name, systemImage: symbol(context.attributes.type))
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(colour)
            .lineLimit(1)
        }
        DynamicIslandExpandedRegion(.trailing) {
          if context.state.paused {
            Text("Paused").font(.subheadline.weight(.semibold)).foregroundStyle(.yellow)
          }
        }
        DynamicIslandExpandedRegion(.bottom) {
          HStack(alignment: .firstTextBaseline) {
            WorkoutClock(state: context.state)
              .font(.largeTitle.weight(.bold))
            Spacer()
            if !context.state.detail.isEmpty {
              Text(context.state.detail).font(.title3.weight(.semibold))
            }
          }
          .foregroundStyle(.white)
        }
      } compactLeading: {
        Image(systemName: symbol(context.attributes.type)).foregroundStyle(colour)
      } compactTrailing: {
        WorkoutClock(state: context.state)
          .frame(maxWidth: 56)
          .foregroundStyle(context.state.paused ? Color.yellow : colour)
      } minimal: {
        Image(systemName: symbol(context.attributes.type)).foregroundStyle(colour)
      }
      .widgetURL(appLink("workout"))
    }
  }
}

struct LockScreenWorkout: View {
  let context: ActivityViewContext<WorkoutAttributes>

  var body: some View {
    let colour = Color(argb: context.attributes.color)
    HStack(spacing: 12) {
      Image(systemName: symbol(context.attributes.type))
        .font(.title2)
        .foregroundStyle(colour)
        .frame(width: 44, height: 44)
        .background(colour.opacity(0.2), in: Circle())
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        Text(context.attributes.name)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.white)
          .lineLimit(1)
        Text(context.state.paused ? "Paused" : (context.state.detail.isEmpty ? "Recording" : context.state.detail))
          .font(.caption)
          .foregroundStyle(context.state.paused ? Color.yellow : Color.white.opacity(0.7))
      }
      Spacer()
      WorkoutClock(state: context.state)
        .font(.title.weight(.bold))
        .foregroundStyle(colour)
    }
  }
}

/// Counts up while running; stands still while paused.
struct WorkoutClock: View {
  let state: WorkoutAttributes.ContentState

  var body: some View {
    Group {
      if state.paused {
        Text(Duration.seconds(state.elapsed).formatted(.time(pattern: state.elapsed >= 3600 ? .hourMinuteSecond : .minuteSecond)))
      } else {
        Text(timerInterval: state.start...Date.distantFuture, countsDown: false)
      }
    }
    .monospacedDigit()
    .multilineTextAlignment(.trailing)
    .lineLimit(1)
  }
}

/// The SF Symbol for the app's workout type name.
func symbol(_ type: String) -> String {
  switch type {
  case "run", "indoorRun": return "figure.run"
  case "walk": return "figure.walk"
  case "hike": return "figure.hiking"
  case "cycle": return "figure.outdoor.cycle"
  case "indoorCycle": return "figure.indoor.cycle"
  case "strength": return "dumbbell.fill"
  case "hiit": return "figure.highintensity.intervaltraining"
  case "swim", "openWaterSwim": return "figure.pool.swim"
  case "row", "kayaking": return "figure.rower"
  case "elliptical": return "figure.elliptical"
  case "yoga": return "figure.yoga"
  case "dance": return "figure.dance"
  case "stairs": return "figure.stairs"
  case "jumpRope": return "figure.jumprope"
  case "boxing": return "figure.boxing"
  case "martialArts": return "figure.martial.arts"
  case "climbing": return "figure.climbing"
  case "pilates": return "figure.pilates"
  case "stretching": return "figure.flexibility"
  case "taiChi": return "figure.taichi"
  case "tennis": return "figure.tennis"
  case "skiing": return "figure.skiing.downhill"
  case "snowboarding": return "figure.snowboarding"
  case "surfing", "paddleboard": return "figure.surfing"
  case "skateboarding": return "figure.skateboarding"
  case "golf": return "figure.golf"
  case "fencing": return "figure.fencing"
  default: return "figure.mixed.cardio"
  }
}
