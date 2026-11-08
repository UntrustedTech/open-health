import 'package:health_app/models/cycle.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/models/workout.dart';
import 'package:health_app/sync/health_sample.dart';

/// Whether the phone's health platform can be used.
enum SourceStatus {
  /// This device can't use it (e.g. Android older than 8.0).
  unsupported,

  /// Health Connect must be installed or updated (Android 13 and older).
  needsInstall,

  /// Ready to request permission and read data.
  available,
}

/// Profile details the platform keeps; null where it has none.
typedef ProfileFacts = ({
  DateTime? birthDate,

  /// 'Female', 'Male' or 'Other'.
  String? sex,

  /// e.g. 'A+' or 'O−' (with a minus sign).
  String? bloodType,
  double? heightCm,
});

/// The answer to asking for background access.
enum BackgroundAccess {
  allowed,

  /// The user said no.
  denied,

  /// This phone's Health Connect can't read in the background.
  unavailable,
}

/// The phone's health platform: Health Connect on Android, Apple Health on
/// iOS. The app only reads from it and never writes.
abstract interface class HealthSource {
  /// Display name, e.g. "Health Connect".
  String get name;

  /// Metrics this platform can provide.
  Set<MetricType> get supportedTypes;

  Future<SourceStatus> status();

  /// Opens the store page to install or update the platform.
  Future<void> openInstallPage();

  /// Shows the system permission screen; returns the metrics now readable.
  Future<Set<MetricType>> requestAccess();

  /// Whether the platform has yet to ask the user. Apple Health asks only
  /// once, and until it has nothing can be read, with no error to say so.
  Future<bool> needsAccessRequest();

  /// Metrics the user has currently allowed.
  Future<Set<MetricType>> grantedTypes();

  /// Asks to read data older than 30 days; returns whether it is allowed.
  Future<bool> requestHistoryAccess();

  /// Reads samples of [type] between [from] and [to], in app units.
  Future<List<HealthSample>> read(MetricType type, DateTime from, DateTime to);

  /// Workouts recorded by other apps (not this one) between [from] and [to].
  Future<List<WorkoutSession>> readWorkouts(DateTime from, DateTime to);

  /// Asks to save workouts (with distance and calories); returns whether
  /// it is allowed.
  Future<bool> requestWriteAccess();

  /// Saves a workout recorded in this app. Returns false on failure.
  Future<bool> writeWorkout(
    WorkoutSession workout, {
    required double totalKcal,
  });

  /// Withdraws all permissions the app was given.
  Future<void> revokeAccess();

  /// Asks to read data while the app is in the background.
  Future<BackgroundAccess> requestBackgroundAccess();

  /// Whether reading in the background is allowed now (it can be removed
  /// in the platform's settings at any time).
  Future<bool> hasBackgroundAccess();

  /// Opens the platform's page of this app's permissions, where the user
  /// can allow or remove each type of data.
  Future<void> openPermissionSettings();

  /// Opens the platform's "Data and access" screen: its data by type,
  /// and the apps that can use it.
  Future<void> openDataSettings();

  /// Asks to read the profile details the platform keeps (birth date, sex
  /// and blood type in Apple Health; height on both) and returns them.
  Future<ProfileFacts> readProfile();

  /// Asks to read menstruation and returns the flow logged on each day
  /// between [from] and [to] (dates only).
  Future<Map<DateTime, PeriodFlow>> readPeriodDays(DateTime from, DateTime to);
}
