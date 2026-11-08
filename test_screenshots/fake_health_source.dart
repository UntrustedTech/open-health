import 'package:health_app/models/cycle.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/models/workout.dart';
import 'package:health_app/sync/health_sample.dart';
import 'package:health_app/sync/health_source.dart';

/// In-memory stand-in for Health Connect used by tests.
class FakeHealthSource implements HealthSource {
  FakeHealthSource({
    this.currentStatus = SourceStatus.available,
    Set<MetricType>? grant,
    this.historyAllowed = true,
  }) : grant = grant ?? {MetricType.steps, MetricType.weight};

  SourceStatus currentStatus;
  Set<MetricType> grant;
  bool historyAllowed;
  final List<HealthSample> samples = [];
  final List<WorkoutSession> workouts = [];
  final List<WorkoutSession> written = [];
  bool writeAllowed = true;
  final Set<MetricType> failing = {};
  final List<(MetricType, DateTime, DateTime)> reads = [];
  Set<MetricType> _granted = {};
  bool revoked = false;

  @override
  String get name => 'Health Connect';

  @override
  Set<MetricType> get supportedTypes =>
      MetricType.values.toSet()..remove(MetricType.mindfulMinutes);

  @override
  Future<SourceStatus> status() async => currentStatus;

  @override
  Future<void> openInstallPage() async {}

  @override
  Future<Set<MetricType>> requestAccess() async => _granted = {...grant};

  @override
  Future<bool> needsAccessRequest() async => false;

  @override
  Future<Set<MetricType>> grantedTypes() async => {..._granted};

  @override
  Future<bool> requestHistoryAccess() async => historyAllowed;

  @override
  Future<List<HealthSample>> read(
    MetricType type,
    DateTime from,
    DateTime to,
  ) async {
    reads.add((type, from, to));
    if (failing.contains(type)) throw Exception('read failed');
    return [
      for (final s in samples)
        if (s.type == type && !s.start.isBefore(from) && s.start.isBefore(to))
          s,
    ];
  }

  @override
  Future<List<WorkoutSession>> readWorkouts(DateTime from, DateTime to) async =>
      [
        for (final w in workouts)
          if (!w.start.isBefore(from) && w.start.isBefore(to)) w,
      ];

  @override
  Future<bool> requestWriteAccess() async => writeAllowed;

  @override
  Future<bool> writeWorkout(
    WorkoutSession workout, {
    required double totalKcal,
  }) async {
    if (!writeAllowed) return false;
    written.add(workout);
    return true;
  }

  @override
  Future<void> revokeAccess() async {
    revoked = true;
    _granted = {};
  }

  @override
  Future<BackgroundAccess> requestBackgroundAccess() async =>
      BackgroundAccess.allowed;

  @override
  Future<bool> hasBackgroundAccess() async => true;

  @override
  Future<void> openPermissionSettings() async {}

  @override
  Future<void> openDataSettings() async {}

  @override
  Future<ProfileFacts> readProfile() async =>
      (birthDate: null, sex: null, bloodType: null, heightCm: null);

  @override
  Future<Map<DateTime, PeriodFlow>> readPeriodDays(
    DateTime from,
    DateTime to,
  ) async => const {};
}
