import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:health/health.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:health_app/models/cycle.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/models/workout.dart';
import 'package:health_app/sync/health_sample.dart';
import 'package:health_app/sync/health_source.dart';

/// How one app metric is read from the platform.
typedef _Mapping = ({
  HealthDataType type,

  /// Totals per hour computed by the platform, which removes duplicates when
  /// several apps (e.g. phone and watch) count the same steps.
  bool hourlyTotals,

  /// Converts a platform value to app units.
  double Function(double) convert,

  /// More types read together with [type] as one metric. Their values are
  /// span lengths, so overlapping spans are merged rather than added.
  List<HealthDataType> also,

  /// Picks this metric's number out of a food record.
  double? Function(NutritionHealthValue)? nutrient,
});

double _same(double v) => v;

double _minutesToHours(double minutes) => minutes / 60;

_Mapping _read(
  HealthDataType type, {
  bool hourlyTotals = false,
  double Function(double) convert = _same,
  List<HealthDataType> also = const [],
  double? Function(NutritionHealthValue)? nutrient,
}) => (
  type: type,
  hourlyTotals: hourlyTotals,
  convert: convert,
  also: also,
  nutrient: nutrient,
);

/// Reads from Health Connect on Android and Apple Health on iOS through the
/// `health` package. This is the only file that depends on that package.
class HealthConnectSource implements HealthSource {
  HealthConnectSource({Health? health}) : _health = health ?? Health();

  final Health _health;
  bool _configured = false;

  /// This app's package, used to skip data it wrote itself.
  static const ownPackage = 'health.untrustedtech.dev';

  /// This app's bundle ID on iOS, where installing (e.g. with xtool) can
  /// change it.
  String? _ownBundleId;

  bool _isOwn(HealthDataPoint p) =>
      p.sourceName == ownPackage ||
      p.sourceId == ownPackage ||
      (_ownBundleId != null && p.sourceId == _ownBundleId);

  static final Map<WorkoutType, HealthWorkoutActivityType> _toPlatform = {
    WorkoutType.run: HealthWorkoutActivityType.RUNNING,
    WorkoutType.walk: HealthWorkoutActivityType.WALKING,
    WorkoutType.hike: HealthWorkoutActivityType.HIKING,
    WorkoutType.cycle: HealthWorkoutActivityType.BIKING,
    WorkoutType.strength: Platform.isIOS
        ? HealthWorkoutActivityType.TRADITIONAL_STRENGTH_TRAINING
        : HealthWorkoutActivityType.STRENGTH_TRAINING,
    WorkoutType.hiit:
        HealthWorkoutActivityType.HIGH_INTENSITY_INTERVAL_TRAINING,
    WorkoutType.swim: HealthWorkoutActivityType.SWIMMING_POOL,
    WorkoutType.row: HealthWorkoutActivityType.ROWING,
    WorkoutType.elliptical: HealthWorkoutActivityType.ELLIPTICAL,
    WorkoutType.yoga: HealthWorkoutActivityType.YOGA,
    WorkoutType.dance: HealthWorkoutActivityType.DANCING,
    WorkoutType.indoorRun: Platform.isIOS
        ? HealthWorkoutActivityType.RUNNING
        : HealthWorkoutActivityType.RUNNING_TREADMILL,
    WorkoutType.indoorCycle: HealthWorkoutActivityType.BIKING,
    WorkoutType.stairs: Platform.isIOS
        ? HealthWorkoutActivityType.STAIR_CLIMBING
        : HealthWorkoutActivityType.STAIR_CLIMBING_MACHINE,
    WorkoutType.jumpRope: Platform.isIOS
        ? HealthWorkoutActivityType.JUMP_ROPE
        : HealthWorkoutActivityType.OTHER,
    WorkoutType.boxing: HealthWorkoutActivityType.BOXING,
    WorkoutType.martialArts: HealthWorkoutActivityType.MARTIAL_ARTS,
    WorkoutType.climbing: Platform.isIOS
        ? HealthWorkoutActivityType.CLIMBING
        : HealthWorkoutActivityType.ROCK_CLIMBING,
    WorkoutType.pilates: HealthWorkoutActivityType.PILATES,
    WorkoutType.barre: Platform.isIOS
        ? HealthWorkoutActivityType.BARRE
        : HealthWorkoutActivityType.OTHER,
    WorkoutType.stretching: HealthWorkoutActivityType.OTHER,
    WorkoutType.taiChi: Platform.isIOS
        ? HealthWorkoutActivityType.TAI_CHI
        : HealthWorkoutActivityType.OTHER,
    WorkoutType.tennis: HealthWorkoutActivityType.TENNIS,
    WorkoutType.aerialSilks: HealthWorkoutActivityType.GYMNASTICS,
    WorkoutType.aerialHoop: HealthWorkoutActivityType.GYMNASTICS,
    WorkoutType.poleFitness: HealthWorkoutActivityType.GYMNASTICS,
    WorkoutType.trampoline: HealthWorkoutActivityType.GYMNASTICS,
    WorkoutType.paragliding: Platform.isIOS
        ? HealthWorkoutActivityType.OTHER
        : HealthWorkoutActivityType.PARAGLIDING,
    WorkoutType.surfing: HealthWorkoutActivityType.SURFING,
    WorkoutType.paddleboard: Platform.isIOS
        ? HealthWorkoutActivityType.PADDLE_SPORTS
        : HealthWorkoutActivityType.OTHER,
    WorkoutType.kayaking: Platform.isIOS
        ? HealthWorkoutActivityType.PADDLE_SPORTS
        : HealthWorkoutActivityType.OTHER,
    WorkoutType.skiing: Platform.isIOS
        ? HealthWorkoutActivityType.DOWNHILL_SKIING
        : HealthWorkoutActivityType.SKIING,
    WorkoutType.snowboarding: HealthWorkoutActivityType.SNOWBOARDING,
    WorkoutType.skateboarding: Platform.isIOS
        ? HealthWorkoutActivityType.OTHER
        : HealthWorkoutActivityType.SKATING,
    WorkoutType.parkour: Platform.isIOS
        ? HealthWorkoutActivityType.CROSS_TRAINING
        : HealthWorkoutActivityType.CALISTHENICS,
    WorkoutType.openWaterSwim: Platform.isIOS
        ? HealthWorkoutActivityType.SWIMMING
        : HealthWorkoutActivityType.SWIMMING_OPEN_WATER,
    WorkoutType.fencing: HealthWorkoutActivityType.FENCING,
    WorkoutType.golf: HealthWorkoutActivityType.GOLF,
    WorkoutType.other: HealthWorkoutActivityType.OTHER,
  };

  static WorkoutType _fromPlatform(HealthWorkoutActivityType t) => switch (t) {
    HealthWorkoutActivityType.RUNNING => WorkoutType.run,
    HealthWorkoutActivityType.RUNNING_TREADMILL => WorkoutType.indoorRun,
    HealthWorkoutActivityType.STAIR_CLIMBING ||
    HealthWorkoutActivityType.STAIR_CLIMBING_MACHINE ||
    HealthWorkoutActivityType.STAIRS => WorkoutType.stairs,
    HealthWorkoutActivityType.JUMP_ROPE => WorkoutType.jumpRope,
    HealthWorkoutActivityType.BOXING ||
    HealthWorkoutActivityType.KICKBOXING => WorkoutType.boxing,
    HealthWorkoutActivityType.MARTIAL_ARTS => WorkoutType.martialArts,
    HealthWorkoutActivityType.CLIMBING ||
    HealthWorkoutActivityType.ROCK_CLIMBING => WorkoutType.climbing,
    HealthWorkoutActivityType.PILATES => WorkoutType.pilates,
    HealthWorkoutActivityType.BARRE => WorkoutType.barre,
    HealthWorkoutActivityType.TAI_CHI => WorkoutType.taiChi,
    HealthWorkoutActivityType.TENNIS => WorkoutType.tennis,
    HealthWorkoutActivityType.WALKING => WorkoutType.walk,
    HealthWorkoutActivityType.HIKING => WorkoutType.hike,
    HealthWorkoutActivityType.BIKING => WorkoutType.cycle,
    HealthWorkoutActivityType.STRENGTH_TRAINING ||
    HealthWorkoutActivityType.TRADITIONAL_STRENGTH_TRAINING ||
    HealthWorkoutActivityType.FUNCTIONAL_STRENGTH_TRAINING =>
      WorkoutType.strength,
    HealthWorkoutActivityType.HIGH_INTENSITY_INTERVAL_TRAINING =>
      WorkoutType.hiit,
    HealthWorkoutActivityType.SWIMMING_POOL => WorkoutType.swim,
    HealthWorkoutActivityType.ROWING => WorkoutType.row,
    HealthWorkoutActivityType.ELLIPTICAL => WorkoutType.elliptical,
    HealthWorkoutActivityType.YOGA => WorkoutType.yoga,
    HealthWorkoutActivityType.DANCING ||
    HealthWorkoutActivityType.CARDIO_DANCE ||
    HealthWorkoutActivityType.SOCIAL_DANCE => WorkoutType.dance,
    HealthWorkoutActivityType.ROWING_MACHINE => WorkoutType.row,
    HealthWorkoutActivityType.BIKING_STATIONARY => WorkoutType.indoorCycle,
    HealthWorkoutActivityType.WEIGHTLIFTING => WorkoutType.strength,
    HealthWorkoutActivityType.SWIMMING => WorkoutType.swim,
    HealthWorkoutActivityType.GYMNASTICS => WorkoutType.trampoline,
    HealthWorkoutActivityType.PARAGLIDING => WorkoutType.paragliding,
    HealthWorkoutActivityType.SURFING => WorkoutType.surfing,
    HealthWorkoutActivityType.PADDLE_SPORTS => WorkoutType.kayaking,
    HealthWorkoutActivityType.SKIING ||
    HealthWorkoutActivityType.DOWNHILL_SKIING ||
    HealthWorkoutActivityType.CROSS_COUNTRY_SKIING => WorkoutType.skiing,
    HealthWorkoutActivityType.SNOWBOARDING => WorkoutType.snowboarding,
    HealthWorkoutActivityType.SKATING => WorkoutType.skateboarding,
    HealthWorkoutActivityType.SWIMMING_OPEN_WATER => WorkoutType.openWaterSwim,
    HealthWorkoutActivityType.FENCING => WorkoutType.fencing,
    HealthWorkoutActivityType.GOLF => WorkoutType.golf,
    _ => WorkoutType.other,
  };

  static final Map<MetricType, _Mapping> _mappings = {
    MetricType.steps: _read(HealthDataType.STEPS, hourlyTotals: true),
    MetricType.distance: _read(
      Platform.isIOS
          ? HealthDataType.DISTANCE_WALKING_RUNNING
          : HealthDataType.DISTANCE_DELTA,
      hourlyTotals: true,
      convert: (m) => m / 1000,
    ),
    MetricType.activeEnergy: _read(
      HealthDataType.ACTIVE_ENERGY_BURNED,
      hourlyTotals: true,
    ),
    MetricType.exerciseMinutes: _read(HealthDataType.WORKOUT),
    // Health Connect gives a daily rate (kcal per day), so readings are
    // averaged; Apple Health's are amounts per span and would need adding.
    if (!Platform.isIOS)
      MetricType.restingEnergy: _read(HealthDataType.BASAL_ENERGY_BURNED),
    MetricType.floorsClimbed: _read(HealthDataType.FLIGHTS_CLIMBED),
    MetricType.heartRate: _read(HealthDataType.HEART_RATE),
    MetricType.restingHeartRate: _read(HealthDataType.RESTING_HEART_RATE),
    MetricType.bloodOxygen: _read(
      HealthDataType.BLOOD_OXYGEN,
      // Some sources report a fraction (0.97) rather than a percentage.
      convert: (v) => v <= 1 ? v * 100 : v,
    ),
    MetricType.bloodPressureSystolic: _read(
      HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
    ),
    MetricType.bloodPressureDiastolic: _read(
      HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
    ),
    // Read in mg/dL; shown in the user's units.
    MetricType.bloodGlucose: _read(HealthDataType.BLOOD_GLUCOSE),
    // Apple Health has no sessions: sleep is the time in any asleep stage.
    MetricType.sleep: Platform.isIOS
        ? _read(
            HealthDataType.SLEEP_ASLEEP,
            convert: _minutesToHours,
            also: const [
              HealthDataType.SLEEP_LIGHT,
              HealthDataType.SLEEP_DEEP,
              HealthDataType.SLEEP_REM,
            ],
          )
        : _read(HealthDataType.SLEEP_SESSION, convert: _minutesToHours),
    MetricType.hrv: _read(
      Platform.isIOS
          ? HealthDataType.HEART_RATE_VARIABILITY_SDNN
          : HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
    ),
    // Sleep stages arrive as spans in minutes.
    MetricType.sleepDeep: _read(
      HealthDataType.SLEEP_DEEP,
      convert: _minutesToHours,
    ),
    MetricType.sleepCore: _read(
      HealthDataType.SLEEP_LIGHT,
      convert: _minutesToHours,
    ),
    MetricType.sleepRem: _read(
      HealthDataType.SLEEP_REM,
      convert: _minutesToHours,
    ),
    MetricType.sleepAwake: _read(
      HealthDataType.SLEEP_AWAKE,
      convert: _minutesToHours,
      also: [
        if (!Platform.isIOS) ...[
          HealthDataType.SLEEP_AWAKE_IN_BED,
          HealthDataType.SLEEP_OUT_OF_BED,
        ],
      ],
    ),
    MetricType.weight: _read(HealthDataType.WEIGHT),
    MetricType.bodyFat: _read(
      HealthDataType.BODY_FAT_PERCENTAGE,
      // Apple Health reports a fraction (0.22) rather than a percentage.
      convert: (v) => v <= 1 ? v * 100 : v,
    ),
    MetricType.leanBodyMass: _read(HealthDataType.LEAN_BODY_MASS),
    if (!Platform.isIOS)
      MetricType.bodyWaterMass: _read(HealthDataType.BODY_WATER_MASS),
    MetricType.respiratoryRate: _read(HealthDataType.RESPIRATORY_RATE),
    // The change from the wearer's own baseline, in °C.
    if (!Platform.isIOS)
      MetricType.skinTemperature: _read(HealthDataType.SKIN_TEMPERATURE),
    MetricType.bodyTemperature: _read(HealthDataType.BODY_TEMPERATURE),
    // Food logged in other apps, one record per food or meal.
    MetricType.dietaryEnergy: _read(
      HealthDataType.NUTRITION,
      nutrient: (n) => n.calories,
    ),
    MetricType.protein: _read(
      HealthDataType.NUTRITION,
      nutrient: (n) => n.protein,
    ),
    MetricType.carbs: _read(HealthDataType.NUTRITION, nutrient: (n) => n.carbs),
    MetricType.fat: _read(HealthDataType.NUTRITION, nutrient: (n) => n.fat),
    MetricType.water: _read(
      HealthDataType.WATER,
      convert: (litres) => litres * 1000,
    ),
    if (Platform.isIOS)
      MetricType.mindfulMinutes: _read(HealthDataType.MINDFULNESS),
  };

  @override
  String get name => Platform.isIOS ? 'Apple Health' : 'Health Connect';

  @override
  Set<MetricType> get supportedTypes => _mappings.keys.toSet();

  // Several metrics share a type (food), so each is asked for once.
  List<HealthDataType> get _platformTypes => {
    for (final m in _mappings.values) ...[m.type, ...m.also],
  }.toList();

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _health.configure();
    if (Platform.isIOS) {
      _ownBundleId = (await PackageInfo.fromPlatform()).packageName;
    }
    _configured = true;
  }

  @override
  Future<SourceStatus> status() async {
    // Every iPhone has Apple Health.
    if (Platform.isIOS) return SourceStatus.available;
    if (!Platform.isAndroid) return SourceStatus.unsupported;
    await _ensureConfigured();
    return switch (await _health.getHealthConnectSdkStatus()) {
      HealthConnectSdkStatus.sdkAvailable => SourceStatus.available,
      HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired =>
        SourceStatus.needsInstall,
      HealthConnectSdkStatus.sdkUnavailable || null => SourceStatus.unsupported,
    };
  }

  @override
  Future<void> openInstallPage() async {
    await _ensureConfigured();
    await _health.installHealthConnect();
  }

  @override
  Future<Set<MetricType>> requestAccess() async {
    await _ensureConfigured();
    final types = _platformTypes;
    final shown = await _health.requestAuthorization(
      types,
      permissions: [for (final _ in types) HealthDataAccess.READ],
    );
    // On iOS false means the permission sheet couldn't be shown, e.g. the
    // app was signed without HealthKit. Every type would then read empty.
    if (Platform.isIOS && !shown) {
      throw PlatformException(
        code: 'healthkit-refused',
        message: 'Apple Health refused the permission request',
      );
    }
    // Still not asked: the sheet never came up. (Fails with HealthKit's
    // reason when it can't be used at all.)
    if (await needsAccessRequest()) {
      throw PlatformException(
        code: 'healthkit-not-asked',
        message: 'Apple Health did not show its permission sheet',
      );
    }
    return grantedTypes();
  }

  @override
  Future<bool> needsAccessRequest() async {
    // Health Connect asks every time; its answers can be checked.
    if (!Platform.isIOS) return false;
    return await _screens.invokeMethod<String>('authStatus') == 'shouldRequest';
  }

  @override
  Future<Set<MetricType>> grantedTypes() async {
    // Apple Health never reveals read access (a refused type just reads as
    // empty), so everything asked for counts as shared.
    if (Platform.isIOS) return supportedTypes;
    await _ensureConfigured();
    final granted = <MetricType>{};
    for (final MapEntry(key: metric, value: m) in _mappings.entries) {
      final ok = await _health.hasPermissions(
        [m.type],
        permissions: [HealthDataAccess.READ],
      );
      // Null means Health Connect couldn't say: report the check as
      // failed rather than as "not shared", which would remove data.
      if (ok == null) throw PermissionUnknownException(metric);
      if (ok) granted.add(metric);
    }
    return granted;
  }

  @override
  Future<bool> requestHistoryAccess() async {
    // Apple Health has no 30-day limit.
    if (Platform.isIOS) return true;
    await _ensureConfigured();
    if (!await _health.isHealthDataHistoryAvailable()) return false;
    if (await _health.isHealthDataHistoryAuthorized()) return true;
    return _health.requestHealthDataHistoryAuthorization();
  }

  @override
  Future<List<HealthSample>> read(
    MetricType type,
    DateTime from,
    DateTime to,
  ) async {
    final m = _mappings[type];
    if (m == null) return const [];
    await _ensureConfigured();
    final points = m.hourlyTotals
        ? await _health.getHealthIntervalDataFromTypes(
            startDate: from,
            endDate: to,
            types: [m.type],
            interval: Duration.secondsPerHour,
          )
        : await _health.getHealthDataFromTypes(
            types: [m.type, ...m.also],
            startTime: from,
            endTime: to,
          );
    if (m.also.isNotEmpty) {
      return [
        for (final (start, end) in _mergeSpans(points.where((p) => !_isOwn(p))))
          HealthSample(
            type: type,
            value: m.convert(end.difference(start).inSeconds / 60),
            start: start,
            end: end,
          ),
      ];
    }
    return [
      for (final p in points)
        if (!_isOwn(p)) ?_sample(type, m, p),
    ];
  }

  static HealthSample? _sample(MetricType type, _Mapping m, HealthDataPoint p) {
    final value = switch (p.value) {
      NutritionHealthValue n => m.nutrient?.call(n),
      NumericHealthValue(:final numericValue) => numericValue.toDouble(),
      // Workouts carry a summary, not a number; their length is used.
      _ when p.type == HealthDataType.WORKOUT => 0.0,
      _ => null,
    };
    if (value == null) return null;
    return HealthSample(
      type: type,
      value: m.convert(value),
      start: p.dateFrom,
      end: p.dateTo,
    );
  }

  @override
  Future<List<WorkoutSession>> readWorkouts(DateTime from, DateTime to) async {
    await _ensureConfigured();
    final points = await _health.getHealthDataFromTypes(
      types: [HealthDataType.WORKOUT],
      startTime: from,
      endTime: to,
    );
    return [
      for (final p in points)
        if (!_isOwn(p) && p.dateTo.isAfter(p.dateFrom))
          WorkoutSession(
            id: 'hc-${p.uuid}',
            type: p.value is WorkoutHealthValue
                ? _fromPlatform(
                    (p.value as WorkoutHealthValue).workoutActivityType,
                  )
                : WorkoutType.other,
            start: p.dateFrom,
            end: p.dateTo,
            activeSeconds: p.dateTo.difference(p.dateFrom).inSeconds,
            distanceMeters: switch (p.value) {
              WorkoutHealthValue(:final totalDistance?) =>
                totalDistance.toDouble(),
              _ => 0,
            },
            activeKcal: switch (p.value) {
              WorkoutHealthValue(:final totalEnergyBurned?) =>
                totalEnergyBurned.toDouble(),
              _ => 0,
            },
            notes: p.sourceName,
            source: WorkoutSource.healthConnect,
          ),
    ];
  }

  /// Joins overlapping spans, e.g. the same night from a watch and another
  /// app, so no time is counted twice.
  static List<(DateTime, DateTime)> _mergeSpans(
    Iterable<HealthDataPoint> points,
  ) {
    final sorted = [
      for (final p in points)
        if (p.dateTo.isAfter(p.dateFrom)) (p.dateFrom, p.dateTo),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    final merged = <(DateTime, DateTime)>[];
    for (final span in sorted) {
      if (merged.isNotEmpty && !span.$1.isAfter(merged.last.$2)) {
        final last = merged.removeLast();
        merged.add((last.$1, span.$2.isAfter(last.$2) ? span.$2 : last.$2));
      } else {
        merged.add(span);
      }
    }
    return merged;
  }

  /// On iOS a workout's distance and energy are part of the workout itself.
  static final _writeTypes = Platform.isIOS
      ? const [HealthDataType.WORKOUT]
      : const [
          HealthDataType.WORKOUT,
          HealthDataType.DISTANCE_DELTA,
          HealthDataType.TOTAL_CALORIES_BURNED,
        ];

  @override
  Future<bool> requestWriteAccess() async {
    await _ensureConfigured();
    final access = [for (final _ in _writeTypes) HealthDataAccess.READ_WRITE];
    if (await _health.hasPermissions(_writeTypes, permissions: access) ??
        false) {
      return true;
    }
    return _health.requestAuthorization(_writeTypes, permissions: access);
  }

  @override
  Future<bool> writeWorkout(
    WorkoutSession workout, {
    required double totalKcal,
  }) async {
    await _ensureConfigured();
    return _health.writeWorkoutData(
      activityType:
          _toPlatform[workout.type] ?? HealthWorkoutActivityType.OTHER,
      start: workout.start,
      end: workout.end,
      totalEnergyBurned: totalKcal.round(),
      totalDistance: workout.distanceMeters >= 10
          ? workout.distanceMeters.round()
          : null,
      title: workout.type.label,
      recordingMethod: RecordingMethod.active,
    );
  }

  @override
  Future<void> revokeAccess() async {
    await _ensureConfigured();
    await _health.revokePermissions();
  }

  @override
  Future<BackgroundAccess> requestBackgroundAccess() async {
    // Apple Health has no separate background permission.
    if (Platform.isIOS) return BackgroundAccess.allowed;
    await _ensureConfigured();
    if (!await _health.isHealthDataInBackgroundAvailable()) {
      return BackgroundAccess.unavailable;
    }
    if (await _health.isHealthDataInBackgroundAuthorized() ||
        await _health.requestHealthDataInBackgroundAuthorization()) {
      return BackgroundAccess.allowed;
    }
    return BackgroundAccess.denied;
  }

  @override
  Future<bool> hasBackgroundAccess() async {
    if (Platform.isIOS) return true;
    await _ensureConfigured();
    return await _health.isHealthDataInBackgroundAvailable() &&
        await _health.isHealthDataInBackgroundAuthorized();
  }

  /// Health Connect keeps only height; Apple Health also has birth date,
  /// sex and blood type (from the Health app's profile).
  static final _profileTypes = Platform.isIOS
      ? const [
          HealthDataType.BIRTH_DATE,
          HealthDataType.GENDER,
          HealthDataType.BLOOD_TYPE,
          HealthDataType.HEIGHT,
        ]
      : const [HealthDataType.HEIGHT];

  /// HealthKit's HKBiologicalSex and HKBloodType, by raw value (0 is "not
  /// set").
  static const _sexes = [null, 'Female', 'Male', 'Other'];
  static const _bloodTypes = [
    null,
    'A+',
    'A−',
    'B+',
    'B−',
    'AB+',
    'AB−',
    'O+',
    'O−',
  ];

  @override
  Future<ProfileFacts> readProfile() async {
    await _ensureConfigured();
    final types = _profileTypes;
    final shown = await _health.requestAuthorization(
      types,
      permissions: [for (final _ in types) HealthDataAccess.READ],
    );
    // As in [requestAccess]: on iOS false means no sheet could be shown.
    // (On Android it means height wasn't allowed, which just reads empty.)
    if (Platform.isIOS && !shown) {
      throw PlatformException(
        code: 'healthkit-refused',
        message: 'Apple Health refused the permission request',
      );
    }
    final now = DateTime.now();

    /// The newest value of [type]; characteristics have just one, and 0
    /// where the user hasn't set it.
    Future<num?> newest(HealthDataType type) async {
      final points = await _health.getHealthDataFromTypes(
        types: [type],
        startTime: DateTime(now.year - 30),
        endTime: now,
      );
      HealthDataPoint? last;
      for (final p in points) {
        if (p.value is! NumericHealthValue) continue;
        if (last == null || p.dateTo.isAfter(last.dateTo)) last = p;
      }
      return switch (last?.value) {
        NumericHealthValue(:final numericValue) when numericValue != 0 =>
          numericValue,
        _ => null,
      };
    }

    String? named(List<String?> names, num? raw) => switch (raw?.toInt()) {
      final i? when i > 0 && i < names.length => names[i],
      _ => null,
    };

    final heightM = await newest(HealthDataType.HEIGHT);
    if (!Platform.isIOS) {
      return (
        birthDate: null,
        sex: null,
        bloodType: null,
        heightCm: _plausibleHeight(heightM),
      );
    }
    // Seconds since 1970 for the local midnight of the birthday.
    final born = await newest(HealthDataType.BIRTH_DATE);
    final birth = born == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch((born * 1000).round());
    return (
      birthDate: birth == null
          ? null
          : DateTime(birth.year, birth.month, birth.day),
      sex: named(_sexes, await newest(HealthDataType.GENDER)),
      bloodType: named(_bloodTypes, await newest(HealthDataType.BLOOD_TYPE)),
      heightCm: _plausibleHeight(heightM),
    );
  }

  @override
  Future<Map<DateTime, PeriodFlow>> readPeriodDays(
    DateTime from,
    DateTime to,
  ) async {
    await _ensureConfigured();
    const types = [HealthDataType.MENSTRUATION_FLOW];
    final shown = await _health.requestAuthorization(
      types,
      permissions: const [HealthDataAccess.READ],
    );
    if (Platform.isIOS && !shown) {
      throw PlatformException(
        code: 'healthkit-refused',
        message: 'Apple Health refused the permission request',
      );
    }
    // Refused, Health Connect reads as empty: say so rather than "nothing".
    if (!Platform.isIOS &&
        await _health.hasPermissions(
              types,
              permissions: const [HealthDataAccess.READ],
            ) !=
            true) {
      throw PlatformException(
        code: 'not-allowed',
        message: 'Menstruation is not allowed in Health Connect',
      );
    }
    final points = await _health.getHealthDataFromTypes(
      types: types,
      startTime: from,
      endTime: to,
    );
    return periodDays(points.map((p) => p.value));
  }

  /// The flow of each day in [values]; "none" is not a period day, and an
  /// unspecified flow counts as medium. The heaviest entry of a day wins.
  @visibleForTesting
  static Map<DateTime, PeriodFlow> periodDays(Iterable<HealthValue> values) {
    final days = <DateTime, PeriodFlow>{};
    for (final v in values) {
      if (v is! MenstruationFlowHealthValue) continue;
      final flow = switch (v.flow) {
        MenstrualFlow.none => null,
        MenstrualFlow.spotting => PeriodFlow.spotting,
        MenstrualFlow.light => PeriodFlow.light,
        MenstrualFlow.heavy => PeriodFlow.heavy,
        MenstrualFlow.medium ||
        MenstrualFlow.unspecified ||
        null => PeriodFlow.medium,
      };
      if (flow == null) continue;
      final d = dateOnly(v.dateTime);
      if (days[d] case final had? when had.index >= flow.index) continue;
      days[d] = flow;
    }
    return days;
  }

  /// Metres to centimetres, ignoring values no person could be.
  static double? _plausibleHeight(num? metres) => switch (metres) {
    final m? when m >= 0.5 && m <= 2.75 => m * 100.0,
    _ => null,
  };

  /// Opens Health Connect's own screens (see MainActivity); on iOS, this
  /// app's Settings page and the Health app (see AppDelegate).
  static const _screens = MethodChannel('health/connect');

  @override
  Future<void> openPermissionSettings() => _open('openPermissions');

  @override
  Future<void> openDataSettings() => _open('openData');

  /// Throws when nothing could be opened (e.g. Health Connect missing).
  static Future<void> _open(String method) async {
    if (await _screens.invokeMethod<bool>(method) != true) {
      throw PlatformException(
        code: 'not-found',
        message: 'Health Connect could not be opened',
      );
    }
  }
}

/// Health Connect couldn't tell whether [metric] is shared.
class PermissionUnknownException implements Exception {
  const PermissionUnknownException(this.metric);

  final MetricType metric;

  @override
  String toString() => 'Permission for ${metric.name} is unknown';
}
