import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import 'package:health_app/utils/log.dart';
import 'package:health_app/data/health_repository.dart';
import 'package:health_app/data/write_queue.dart';
import 'package:health_app/data/sample_data.dart';
import 'package:health_app/models/body_goal.dart';
import 'package:health_app/models/board.dart';
import 'package:health_app/models/board_catalog.dart';
import 'package:health_app/models/health_entry.dart';
import 'package:health_app/models/health_widget.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/models/personalization.dart';
import 'package:health_app/models/user_profile.dart';
import 'package:health_app/utils/units.dart';

typedef Clock = DateTime Function();

/// The most recent day that has data for a metric.
typedef DailyReading = ({DateTime day, double value});

/// One reading and when it was taken.
typedef LiveReading = ({DateTime at, double value});

/// Summary statistics over a range of daily values.
typedef RangeStats = ({
  double average,
  double min,
  double max,
  int daysWithData,
});

/// Single source of truth for the app's data. Screens read from it and call
/// its methods to change data; every change is persisted and broadcast.
class HealthStore extends ChangeNotifier {
  HealthStore(this._repo, {Clock? clock, WriteQueue? queue})
    : _clock = clock ?? DateTime.now,
      queue = queue ?? WriteQueue() {
    this.queue.addListener(notifyListeners);
  }

  /// Shared, ordered write queue (also used by the workout store).
  final WriteQueue queue;

  @override
  void dispose() {
    queue.removeListener(notifyListeners);
    super.dispose();
  }

  static const _profileKey = 'profile';
  static const _goalsKey = 'goals';
  static const bodyGoalKey = 'bodyGoal';
  static const _settingsKey = 'settings';
  static const _liveKey = 'liveReadings';
  static const heartZonesKey = 'heartZones';

  /// Heart rate bands are kept for about this long.
  static const _heartDays = 400;

  static const defaultPinned = [
    MetricType.steps,
    MetricType.heartRate,
    MetricType.sleep,
    MetricType.weight,
  ];

  /// Widgets that start wide; every other widget starts small.
  static const _defaultWide = {MetricType.steps};

  final HealthRepository _repo;
  final Clock _clock;

  List<HealthEntry> _entries = [];
  final Map<MetricType, Map<int, List<HealthEntry>>> _byDay = {};
  final Map<MetricType, List<HealthEntry>> _sortedByType = {};
  UserProfile _profile = const UserProfile();
  Goals _goals = const Goals();
  BodyGoal _bodyGoal = const BodyGoal();
  ThemeMode _themeMode = defaultThemeMode;

  /// The Aurora design is made for dark; Light and System stay available.
  static const defaultThemeMode = ThemeMode.dark;
  Personalization _personalization = const Personalization();
  List<MetricType> _pinned = List.of(defaultPinned);

  /// Widget sizes that differ from small, by metric. Only read from
  /// settings saved before boards, to build the Health board.
  Map<MetricType, WidgetSize> _widgetSizes = _defaultSizes();

  /// Each tab's widgets. Built from the defaults until settings load.
  Map<BoardTab, Board> _boards = _initialBoards(const Personalization(), [
    for (final m in defaultPinned)
      HealthWidget(m, _defaultSizes()[m] ?? WidgetSize.small),
  ]);
  Map<int, List<double>> _heartBins = {};
  bool _heartBinsSample = false;
  bool _onboarded = false;
  bool _loaded = false;

  /// False when reading the entries failed, so saving can't replace them
  /// with only the ones added since.
  bool _entriesReadable = true;
  int _idCounter = 0;

  DateTime get now => _clock();
  DateTime get today => _dateOnly(now);
  UserProfile get profile => _profile;
  Goals get goals => _goals;
  ThemeMode get themeMode => _themeMode;
  Personalization get personalization => _personalization;

  /// The metrics on the Health board, in order.
  List<MetricType> get pinned =>
      List.unmodifiable([for (final w in widgets) w.metric]);

  /// The metric widgets on the Health board, in order, with their sizes.
  List<HealthWidget> get widgets => List.unmodifiable([
    for (final i in board(BoardTab.health).items)
      if (BoardIds.metricOf(i.id) case final m?) HealthWidget(m, i.size),
  ]);

  /// [tab]'s widgets.
  Board board(BoardTab tab) => _boards[tab] ?? const Board([]);

  Future<void> updateBoard(BoardTab tab, Board board) async {
    if (board == this.board(tab)) return;
    _boards = {..._boards, tab: board};
    notifyListeners();
    await _saveSettings();
  }

  static Map<BoardTab, Board> _initialBoards(
    Personalization look,
    List<HealthWidget> pinned,
  ) => {
    for (final t in BoardTab.values)
      t: BoardIds.initial(t, look: look, pinned: pinned),
  };
  bool get onboarded => _onboarded;
  bool get loaded => _loaded;
  bool get hasSampleData => _entries.any((e) => e.isSample);
  bool get isEmpty => _entries.isEmpty;

  /// True when the most recent save failed; the UI shows a warning banner.
  bool get saveFailed => queue.failed;

  /// Count of failed writes so far; see [WriteQueue.failures].
  int get saveFailures => queue.failures;

  /// True when some saved data couldn't be read at launch (its original
  /// is kept as a backup) and the user hasn't dismissed the notice yet.
  bool get showUnreadableNotice =>
      _repo.unreadable.isNotEmpty && !_unreadableDismissed;
  bool _unreadableDismissed = false;

  /// What couldn't be read at launch; see [HealthRepository.unreadable].
  Set<String> get unreadableData => Set.unmodifiable(_repo.unreadable);

  void dismissUnreadableNotice() {
    _unreadableDismissed = true;
    notifyListeners();
  }

  /// Loads everything from storage. Each part is loaded independently so one
  /// unreadable document falls back to defaults instead of blocking startup.
  Future<void> load() async {
    // Start from defaults, so a reload (after a restore) can't keep
    // settings whose documents are gone.
    _resetSettings();
    await _loadInto(bodyGoalKey, (json) => _bodyGoal = BodyGoal.fromJson(json));
    _entriesReadable = false;
    await _tryLoad(() async {
      _setEntries(await _repo.loadEntries());
      _entriesReadable = true;
    });
    await _loadInto(
      _profileKey,
      (json) => _profile = UserProfile.fromJson(json),
    );
    await _loadInto(_goalsKey, (json) => _goals = Goals.fromJson(json));
    await _loadInto(_settingsKey, _applySettings);
    _live = {};
    await _loadInto(_liveKey, (json) => _live = _readLive(json));
    _heartBins = {};
    _heartBinsSample = false;
    await _loadInto(heartZonesKey, _applyHeartBins);
    _loaded = true;
    notifyListeners();
  }

  void _resetSettings() {
    _profile = const UserProfile();
    _goals = const Goals();
    _bodyGoal = const BodyGoal();
    _themeMode = defaultThemeMode;
    _personalization = const Personalization();
    Units.system = UnitSystem.metric;
    _pinned = List.of(defaultPinned);
    _widgetSizes = _defaultSizes();
    _boards = _initialBoards(const Personalization(), _legacyWidgets());
  }

  /// Reads document [key] and hands it to [apply] when it exists.
  Future<void> _loadInto(
    String key,
    void Function(Map<String, Object?> json) apply,
  ) => _tryLoad(() async {
    final json = await _repo.loadDocument(key);
    if (json != null) apply(json);
  });

  Future<void> _tryLoad(Future<void> Function() load) async {
    try {
      await load();
      // Anything, even a bug parsing old data, must not stop the app from
      // starting; the original is kept (see HealthRepository).
      // ignore: avoid_catches_without_on_clauses
    } catch (e, st) {
      logError('HealthStore: failed to load data: $e\n$st');
    }
  }

  /// Rebuilds listeners so date-based values (e.g. "today") are recomputed,
  /// for example after midnight or when the app returns to the foreground.
  void refresh() => notifyListeners();

  // ---------------------------------------------------------------- entries

  Future<HealthEntry> addEntry(
    MetricType type,
    double value, {
    DateTime? date,
    String? note,
  }) async {
    final entry = HealthEntry(
      id: '${now.microsecondsSinceEpoch}-${_idCounter++}',
      type: type,
      value: value,
      date: date ?? now,
      note: (note == null || note.trim().isEmpty) ? null : note.trim(),
    );
    _setEntries([..._entries, entry]);
    notifyListeners();
    await _saveEntries();
    return entry;
  }

  /// Adds several entries at once (e.g. those created by a workout).
  Future<void> addEntries(List<HealthEntry> entries) async {
    final ids = {for (final e in entries) e.id};
    _setEntries([
      for (final e in _entries)
        if (!ids.contains(e.id)) e,
      ...entries,
    ]);
    notifyListeners();
    await _saveEntries();
  }

  /// Removes entries whose id starts with [prefix] (e.g. `wk:<id>:`).
  Future<void> removeEntriesWithPrefix(String prefix) async {
    _setEntries(_entries.where((e) => !e.id.startsWith(prefix)).toList());
    notifyListeners();
    await _saveEntries();
  }

  Future<void> deleteEntry(String id) async {
    _setEntries(_entries.where((e) => e.id != id).toList());
    notifyListeners();
    await _saveEntries();
  }

  /// Restores a previously deleted entry (used by "Undo").
  Future<void> restoreEntry(HealthEntry entry) async {
    if (_entries.any((e) => e.id == entry.id)) return;
    _setEntries([..._entries, entry]);
    notifyListeners();
    await _saveEntries();
  }

  /// Restores entries from a backup: [replace] swaps in exactly these
  /// entries; otherwise only those not already here are added. Returns how
  /// many entries were new.
  Future<int> restoreEntries(
    List<HealthEntry> entries, {
    required bool replace,
  }) async {
    final existing = {for (final e in _entries) e.id};
    final fresh = entries.where((e) => !existing.contains(e.id)).toList();
    _setEntries(replace ? [...entries] : [..._entries, ...fresh]);
    // Restoring is how to recover from entries that couldn't be read, so
    // the result must be saved (the unreadable original is kept as a
    // backup copy by the repository), or the restore would be lost.
    _entriesReadable = true;
    notifyListeners();
    await _saveEntries();
    return fresh.length;
  }

  /// How many different days have any data, excluding samples.
  int get daysLogged => {
    for (final e in _entries)
      if (!e.isSample) _dayKey(e.date),
  }.length;

  /// Every entry (for export).
  // A read-only view, not a copy: the list is replaced, never changed.
  List<HealthEntry> get allEntries => UnmodifiableListView(_entries);

  /// Reads one document. Null when there is none; throws when it exists
  /// but can't be read, so callers never mistake damage for "empty".
  Future<Map<String, Object?>?> loadDocument(String key) =>
      _repo.loadDocument(key);

  /// Reads stored documents by key (for export); unreadable ones are left
  /// out and reported to [onSkipped].
  Future<Map<String, Map<String, Object?>>> loadDocuments(
    List<String> keys, {
    void Function(String key)? onSkipped,
  }) async {
    final out = <String, Map<String, Object?>>{};
    for (final k in keys) {
      try {
        final d = await _repo.loadDocument(k);
        if (d != null) out[k] = d;
      } on Exception catch (e) {
        logError('HealthStore: export skipped $k: $e');
        onSkipped?.call(k);
      }
    }
    return out;
  }

  bool get hasImportedData => _entries.any((e) => e.isImported);

  /// Replaces imported entries of [types] dated on or after [from] with
  /// [entries], so data changed or deleted at the source is updated here too.
  /// Estimates are worked out from heart rate (whatever their own type), so
  /// they are only replaced along with heart rate, over its window.
  Future<void> replaceImported({
    required DateTime from,
    required Set<MetricType> types,
    required List<HealthEntry> entries,
  }) async {
    final start = _dateOnly(from);
    bool replaced(HealthEntry e) =>
        e.isImported &&
        types.contains(e.isEstimate ? MetricType.heartRate : e.type) &&
        !e.date.isBefore(start);
    final incoming = {for (final e in entries) e.id: e};
    _setEntries([
      for (final e in _entries)
        if (!replaced(e) && !incoming.containsKey(e.id)) e,
      ...incoming.values,
    ]);
    notifyListeners();
    await _saveEntries();
  }

  /// Removes values the app estimated from imported data.
  Future<void> removeEstimates() async {
    if (!_entries.any((e) => e.isEstimate)) return;
    _setEntries(_entries.where((e) => !e.isEstimate).toList());
    notifyListeners();
    await _saveEntries();
  }

  /// Removes everything imported from the phone's health platform.
  Future<void> removeImported() async {
    _setEntries(_entries.where((e) => !e.isImported).toList());
    _live = {};
    notifyListeners();
    await _saveEntries();
    await _saveLive();
  }

  // ---------------------------------------------------------- live readings

  /// The newest single reading of each averaged metric (heart rate, blood
  /// oxygen...) from the health platform. A day's entry is its average,
  /// which barely moves as readings come in; this is what was measured
  /// last, shown as the metric's latest value.
  Map<MetricType, LiveReading> _live = {};

  LiveReading? liveReading(MetricType type) => _live[type];

  /// Keeps [readings] that are newer than the ones held.
  Future<void> setLiveReadings(Map<MetricType, LiveReading> readings) async {
    var changed = false;
    final next = {..._live};
    for (final MapEntry(key: type, value: r) in readings.entries) {
      final held = next[type];
      if (held == null || r.at.isAfter(held.at)) {
        next[type] = r;
        changed = true;
      }
    }
    if (!changed) return;
    _live = next;
    notifyListeners();
    await _saveLive();
  }

  /// Forgets the live readings of [types] (no longer shared).
  Future<void> clearLiveReadings(Set<MetricType> types) async {
    if (!_live.keys.any(types.contains)) return;
    _live = {
      for (final MapEntry(:key, :value) in _live.entries)
        if (!types.contains(key)) key: value,
    };
    notifyListeners();
    await _saveLive();
  }

  Future<void> _saveLive() => saveDocument(_liveKey, {
    for (final MapEntry(:key, :value) in _live.entries)
      key.name: {'at': value.at.toIso8601String(), 'v': value.value},
  });

  static Map<MetricType, LiveReading> _readLive(Map<String, Object?> json) {
    final out = <MetricType, LiveReading>{};
    for (final MapEntry(:key, :value) in json.entries) {
      final type = MetricType.fromName(key);
      if (type == null || value is! Map || value['v'] is! num) continue;
      final at = DateTime.tryParse('${value['at']}');
      if (at == null) continue;
      out[type] = (at: at, value: (value['v'] as num).toDouble());
    }
    return out;
  }

  /// All entries for a metric, newest first. Cached; do not modify.
  List<HealthEntry> entriesFor(MetricType type) =>
      _sortedByType[type] ?? const [];

  // ------------------------------------------------------------ aggregation

  /// The combined value for one calendar day, or null when nothing was logged.
  double? dailyValue(MetricType type, DateTime day) {
    final entries = _byDay[type]?[_dayKey(day)];
    if (entries == null || entries.isEmpty) return null;
    return switch (type.aggregation) {
      Aggregation.sum => _daySum(entries),
      Aggregation.average =>
        entries.fold<double>(0, (sum, e) => sum + e.value) / entries.length,
      Aggregation.latest =>
        entries.reduce((a, b) => b.date.isAfter(a.date) ? b : a).value,
    };
  }

  /// A workout recorded here, or a watch read directly, may
  /// also reach Health Connect from the same watch, so the largest of the
  /// three counts, plus anything logged by hand.
  static double _daySum(List<HealthEntry> entries) {
    var imported = 0.0, workout = 0.0, plugin = 0.0, other = 0.0;
    for (final e in entries) {
      switch (e.source) {
        case EntrySource.healthConnect:
          imported += e.value;
        case EntrySource.workout:
          workout += e.value;
        case EntrySource.plugin:
          plugin += e.value;
        case EntrySource.manual || EntrySource.sample || EntrySource.food:
          other += e.value;
      }
    }
    return max(max(imported, workout), plugin) + other;
  }

  /// Today's value, treating "no data" as zero.
  double todayValue(MetricType type) => dailyValue(type, today) ?? 0;

  /// Daily values for [days] consecutive days ending on [end] (inclusive).
  List<double?> dailySeries(
    MetricType type, {
    required DateTime end,
    required int days,
  }) {
    final last = _dateOnly(end);
    return [
      for (var i = days - 1; i >= 0; i--)
        dailyValue(type, DateTime(last.year, last.month, last.day - i)),
    ];
  }

  /// Average daily value per calendar month for the [months] months ending
  /// with the month containing [end].
  List<double?> monthlySeries(
    MetricType type, {
    required DateTime end,
    required int months,
  }) {
    return [
      for (var i = months - 1; i >= 0; i--)
        _monthAverage(type, DateTime(end.year, end.month - i)),
    ];
  }

  double? _monthAverage(MetricType type, DateTime month) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final values = [
      for (var d = 1; d <= daysInMonth; d++)
        dailyValue(type, DateTime(month.year, month.month, d)),
    ].nonNulls;
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  /// The most recent day with data, looking back at most [lookbackDays].
  /// For averaged metrics measured often (heart rate), the value is the
  /// newest reading on that day rather than the day's average.
  DailyReading? latestReading(MetricType type, {int lookbackDays = 365}) {
    final t = today;
    final earliest = DateTime(t.year, t.month, t.day - lookbackDays);
    final live = _live[type];
    final liveDay = live == null ? null : _dateOnly(live.at);
    // Sorted newest first; skip future-dated entries.
    for (final entry in entriesFor(type)) {
      final day = _dateOnly(entry.date);
      if (day.isAfter(t)) continue;
      if (day.isBefore(earliest)) return null;
      if (live != null &&
          liveDay != null &&
          !liveDay.isBefore(day) &&
          !liveDay.isAfter(t)) {
        return (day: liveDay, value: live.value);
      }
      final value = dailyValue(type, day);
      return value == null ? null : (day: day, value: value);
    }
    // Only a live reading so far (before it's saved).
    if (live != null &&
        liveDay != null &&
        !liveDay.isBefore(earliest) &&
        !liveDay.isAfter(t)) {
      return (day: liveDay, value: live.value);
    }
    return null;
  }

  static RangeStats? statsOf(List<double?> series) {
    final values = series.nonNulls.toList();
    if (values.isEmpty) return null;
    var min = values.first, max = values.first, sum = 0.0;
    for (final v in values) {
      if (v < min) min = v;
      if (v > max) max = v;
      sum += v;
    }
    return (
      average: sum / values.length,
      min: min,
      max: max,
      daysWithData: values.length,
    );
  }

  /// Progress toward today's goal as 0..∞ (1.0 = goal met), or null if the
  /// metric has no goal.
  double? goalProgress(MetricType type) {
    final goal = _goals.forMetric(type);
    if (goal == null || goal <= 0) return null;
    return (dailyValue(type, today) ?? 0) / goal;
  }

  // -------------------------------------------------------- profile/settings

  Future<void> updateProfile(UserProfile profile) async {
    _profile = profile;
    notifyListeners();
    await _saveProfile();
  }

  Future<void> _saveProfile() {
    final json = _profile.toJson();
    return _enqueue(
      () => _repo.saveDocument(_profileKey, json),
      key: _profileKey,
    );
  }

  Future<void> _saveGoals() {
    final json = _goals.toJson();
    return _enqueue(() => _repo.saveDocument(_goalsKey, json), key: _goalsKey);
  }

  Future<void> updateGoal(MetricType type, double value) async {
    _goals = _goals.withMetric(type, value);
    notifyListeners();
    await _saveGoals();
  }

  /// The user's overall goal (lose, keep or gain weight, or get fitter).
  BodyGoal get bodyGoal => _bodyGoal;

  /// The day of the earliest entry, if any.
  DateTime? get firstEntryDate {
    if (_entries.isEmpty) return null;
    final first = _entries
        .map((e) => e.date)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    return DateTime(first.year, first.month, first.day);
  }

  /// Where the goal's progress is measured from: the weight saved with the
  /// goal, else the first weigh-in since it was set.
  double? get goalStartKg {
    if (_bodyGoal.startKg case final kg?) return kg;
    final since = _bodyGoal.startDate;
    if (since == null) return null;
    final from = DateTime(since.year, since.month, since.day);
    // Newest first, so the last match is the earliest.
    return entriesFor(MetricType.weight)
        .where((e) => !e.date.isBefore(from))
        .lastOrNull
        ?.value;
  }

  Future<void> setBodyGoal(BodyGoal goal) async {
    _bodyGoal = goal;
    notifyListeners();
    final json = goal.toJson();
    await _enqueue(
      () => _repo.saveDocument(bodyGoalKey, json),
      key: bodyGoalKey,
    );
  }

  /// Average daily steps, and how many days had active energy, over the
  /// [days] before today (days without data are left out).
  ({double? averageSteps, int activeDays}) recentActivity({int days = 14}) {
    var stepDays = 0, activeDays = 0;
    var steps = 0.0;
    final t = today;
    for (var i = 1; i <= days; i++) {
      final day = DateTime(t.year, t.month, t.day - i);
      if (dailyValue(MetricType.steps, day) case final v? when v > 0) {
        steps += v;
        stepDays++;
      }
      if ((dailyValue(MetricType.activeEnergy, day) ?? 0) > 0) activeDays++;
    }
    return (
      averageSteps: stepDays >= 3 ? steps / stepDays : null,
      activeDays: activeDays,
    );
  }

  Future<void> setWeightGoal(double? kg) async {
    _goals = _goals.withWeight(kg);
    notifyListeners();
    await _saveGoals();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await _saveSettings();
  }

  /// Saves a new look or Summary layout.
  Future<void> setPersonalization(Personalization next) async {
    if (next == _personalization) return;
    _personalization = next;
    Units.system = next.units;
    notifyListeners();
    await _saveSettings();
  }

  /// Marks a skipped welcome-setup step as done.
  Future<void> completeSetupStep(SetupStep step) async {
    if (!_personalization.setupLeft.contains(step)) return;
    await setPersonalization(_personalization.withSetupDone(step));
  }

  bool isPinned(MetricType type) =>
      board(BoardTab.health).contains(BoardIds.metric(type));

  /// Moves the metric widget at [from] (among the Health board's metric
  /// widgets) so it ends up where the one at [to] is.
  Future<void> movePinned(int from, int to) async {
    final metrics = pinned;
    if (from < 0 || from >= metrics.length || metrics.isEmpty) return;
    final b = board(BoardTab.health);
    final target = metrics[to.clamp(0, metrics.length - 1)];
    await updateBoard(
      BoardTab.health,
      b.withMoved(
        b.indexOf(BoardIds.metric(metrics[from])),
        b.indexOf(BoardIds.metric(target)),
      ),
    );
  }

  Future<void> togglePinned(MetricType type) =>
      isPinned(type) ? removeWidget(type) : addWidget(type);

  static Map<MetricType, WidgetSize> _defaultSizes() => {
    for (final m in _defaultWide) m: WidgetSize.large,
  };

  /// The pinned metrics as read from settings saved before boards.
  List<HealthWidget> _legacyWidgets() => [
    for (final m in _pinned)
      HealthWidget(m, _widgetSizes[m] ?? WidgetSize.small),
  ];

  /// Adds [type] to the Health board as a small widget at the end, unless
  /// it's already there.
  Future<void> addWidget(MetricType type) => updateBoard(
    BoardTab.health,
    board(BoardTab.health).withAdded(BoardIds.metric(type), WidgetSize.small),
  );

  Future<void> removeWidget(MetricType type) => updateBoard(
    BoardTab.health,
    board(BoardTab.health).withRemoved(BoardIds.metric(type)),
  );

  Future<void> setWidgetSize(MetricType type, WidgetSize size) => updateBoard(
    BoardTab.health,
    board(BoardTab.health).withSize(BoardIds.metric(type), size),
  );

  /// Moves the metric widget at [from] so it ends up at [to].
  Future<void> moveWidget(int from, int to) => movePinned(from, to);

  Future<void> completeOnboarding({
    required String name,
    required bool withSampleData,
    Set<SetupStep> setupLeft = const {},
  }) async {
    _profile = _profile.copyWith(name: name.trim());
    _personalization = _personalization.copyWith(setupLeft: setupLeft);
    _onboarded = true;
    if (withSampleData) {
      _setEntries([..._entries, ...generateSampleData(now: now)]);
      _setSampleHeartBins();
    }
    notifyListeners();
    await _saveProfile();
    await _saveEntries();
    await _saveSettings();
    if (withSampleData) await _saveHeartBins();
  }

  Future<void> loadSampleData() async {
    _setEntries([
      ..._entries.where((e) => !e.isSample),
      ...generateSampleData(now: now),
    ]);
    if (_heartBins.isEmpty || _heartBinsSample) _setSampleHeartBins();
    notifyListeners();
    await _saveEntries();
    await _saveHeartBins();
  }

  Future<void> removeSampleData() async {
    _setEntries(_entries.where((e) => !e.isSample).toList());
    if (_heartBinsSample) {
      _heartBins = {};
      _heartBinsSample = false;
    }
    notifyListeners();
    await _saveEntries();
    await _saveHeartBins();
  }

  // ------------------------------------------------------ heart rate zones

  /// Minutes per heart rate band on [day] (see [HeartBins]), if known.
  List<double>? heartBinsOn(DateTime day) => _heartBins[_dayKey(day)];

  bool get hasHeartBins => _heartBins.isNotEmpty;

  /// Stores heart rate bands for the given days (replacing those days).
  /// Real data replaces any sample data.
  Future<void> mergeHeartBins(Map<DateTime, List<double>> days) async {
    if (days.isEmpty) return;
    if (_heartBinsSample) {
      _heartBins = {};
      _heartBinsSample = false;
    }
    _heartBins = {
      ..._heartBins,
      for (final MapEntry(:key, :value) in days.entries)
        _dayKey(key): List.unmodifiable(value),
    };
    notifyListeners();
    await _saveHeartBins();
  }

  /// Removes heart rate bands that came from Health Connect (sample ones
  /// stay with the sample data).
  Future<void> clearImportedHeartBins() async {
    if (_heartBinsSample || _heartBins.isEmpty) return;
    _heartBins = {};
    notifyListeners();
    await _saveHeartBins();
  }

  void _setSampleHeartBins() {
    _heartBins = {
      for (final MapEntry(:key, :value) in generateSampleHeartBins(
        now: now,
      ).entries)
        _dayKey(key): value,
    };
    _heartBinsSample = true;
  }

  void _applyHeartBins(Map<String, Object?> json) {
    final days = json['days'];
    if (days is! Map<String, Object?>) return;
    _heartBins = {
      for (final MapEntry(:key, :value) in days.entries)
        if (int.tryParse(key) case final k? when value is List)
          k: List.unmodifiable([
            for (final v in value) v is num ? v.toDouble() : 0.0,
          ]),
    };
    _heartBinsSample = json['sample'] == true;
  }

  Future<void> _saveHeartBins() {
    final oldest = _dayKey(
      DateTime(today.year, today.month, today.day - _heartDays),
    );
    final json = {
      'sample': _heartBinsSample,
      'days': {
        for (final MapEntry(:key, :value) in _heartBins.entries)
          if (key >= oldest)
            '$key': [for (final v in value) double.parse(v.toStringAsFixed(1))],
      },
    };
    return _enqueue(
      () => _repo.saveDocument(heartZonesKey, json),
      key: heartZonesKey,
    );
  }

  /// Deletes all data and returns the app to onboarding.
  Future<void> eraseAll() async {
    _setEntries([]);
    _entriesReadable = true;
    _resetSettings();
    _heartBins = {};
    _heartBinsSample = false;
    _live = {};
    _onboarded = false;
    notifyListeners();
    await _enqueue(_repo.clear, key: WriteQueue.everything);
  }

  /// Deletes a stored document through the ordered write queue.
  Future<void> deleteDocument(String key) =>
      _enqueue(() => _repo.deleteDocument(key), key: key);

  /// Saves a small settings document through the same ordered write queue,
  /// so it can never be written after a later "Erase All".
  Future<void> saveDocument(String key, Map<String, Object?> json) =>
      _enqueue(() => _repo.saveDocument(key, json), key: key);

  // ---------------------------------------------------------------- helpers

  /// Changes whenever the entries do, for caching derived results.
  int get revision => _revision;
  int _revision = 0;

  void _setEntries(List<HealthEntry> entries) {
    _revision++;
    _entries = entries;
    _byDay.clear();
    _sortedByType.clear();
    for (final e in entries) {
      _byDay
          .putIfAbsent(e.type, () => {})
          .putIfAbsent(_dayKey(e.date), () => [])
          .add(e);
      _sortedByType.putIfAbsent(e.type, () => []).add(e);
    }
    for (final list in _sortedByType.values) {
      list.sort((a, b) => b.date.compareTo(a.date));
    }
    // Sample readings only fill days without real ones, so they never
    // blend into (and hide) real data, e.g. a heart rate average; and an
    // estimate only fills a day without a recorded value.
    for (final days in _byDay.values) {
      for (final list in days.values) {
        if (list.any((e) => !e.isSample)) list.removeWhere((e) => e.isSample);
        if (list.any((e) => !e.isEstimate)) {
          list.removeWhere((e) => e.isEstimate);
        }
      }
    }
  }

  Future<void> _saveEntries() {
    if (!_entriesReadable) {
      logError('HealthStore: not saving over entries that could not be read');
      return Future.value();
    }
    final snapshot = _entries;
    return _enqueue(() => _repo.saveEntries(snapshot), key: entriesKey);
  }

  Future<void> _enqueue(Future<void> Function() write, {String? key}) =>
      queue.run(write, key: key);

  void _applySettings(Map<String, Object?> settings) {
    _onboarded = settings['onboarded'] == true;
    final look = settings['personalization'];
    final mode = ThemeMode.values.firstWhere(
      (m) => m.name == settings['themeMode'],
      orElse: () => defaultThemeMode,
    );
    // Before the redesign the default was System; move it to Dark once.
    final legacy =
        look is! Map<String, Object?> || Personalization.isLegacy(look);
    _themeMode = legacy && mode == ThemeMode.system ? defaultThemeMode : mode;
    _personalization = look is Map<String, Object?>
        ? Personalization.fromJson(look)
        : const Personalization();
    Units.system = _personalization.units;
    final pinned = settings['pinned'];
    if (pinned is List) {
      _pinned = pinned
          .whereType<String>()
          .map(MetricType.fromName)
          .nonNulls
          .toSet()
          .toList();
      // Pins saved before widgets had sizes are all small.
      final sizes = settings['widgetSizes'];
      _widgetSizes = {
        if (sizes is Map)
          for (final MapEntry(:key, :value) in sizes.entries)
            if (MetricType.fromName(key) case final m?)
              if (WidgetSize.fromName(value) != WidgetSize.small)
                m: WidgetSize.fromName(value),
      };
    }
    // Boards saved by this version; earlier settings become boards that
    // follow the sections and pins they had.
    final saved = settings['boards'];
    final initial = _initialBoards(_personalization, _legacyWidgets());
    _boards = {
      for (final t in BoardTab.values)
        t: saved is Map && saved[t.name] is List
            ? Board.fromJson(saved[t.name], known: BoardIds.known(t))
            : initial[t]!,
    };
    // A Health board still as an older version laid it out moves to the
    // tidier layout; one the user arranged is kept as it is.
    if (saved is Map) {
      final health = _boards[BoardTab.health]!.items;
      // The pins as the saved board has them, sizes included (settings
      // never saved their sizes once boards came in).
      final pins = [
        for (final i in health)
          if (BoardIds.metricOf(i.id) case final m?) HealthWidget(m, i.size),
      ];
      final legacy = BoardIds.legacyHealth(_personalization, pins);
      final tidy = BoardIds.initial(
        BoardTab.health,
        look: _personalization,
        pinned: pins,
      );
      if (listEquals(health, legacy) && !listEquals(health, tidy.items)) {
        _boards = {..._boards, BoardTab.health: tidy};
      } else if (listEquals(health, [
        // Less any widget this version doesn't have (the store version's
        // Medications), as loading the board dropped those too.
        for (final i in BoardIds.previousHealthLayout)
          if (BoardIds.known(BoardTab.health).contains(i.id)) i,
      ])) {
        _boards = {
          ..._boards,
          BoardTab.health: const Board(BoardIds.healthLayout),
        };
      }
      // So does a Fitness board as it came: a full card for each section.
      final fitness = _boards[BoardTab.fitness]!.items;
      if (listEquals(
        fitness,
        BoardIds.legacyFitness(const Personalization()),
      )) {
        _boards = {
          ..._boards,
          BoardTab.fitness: const Board(BoardIds.fitnessLayout),
        };
      }
    }
    // Widgets new since these boards were saved join them once.
    final seen = settings['introduced'];
    if (saved is Map) {
      for (final MapEntry(key: id, value: tab) in BoardIds.introduced.entries) {
        final b = _boards[tab]!;
        if ((seen is List && seen.contains(id)) || b.contains(id)) continue;
        final added = b.withAdded(id, WidgetSize.medium);
        _boards = {..._boards, tab: added.withMoved(added.ids.length - 1, 0)};
      }
    }
  }

  Future<void> _saveSettings() {
    final json = {
      'onboarded': _onboarded,
      'themeMode': _themeMode.name,
      // Kept for older versions of the app reading this file.
      'pinned': [for (final p in pinned) p.name],
      'boards': {
        for (final MapEntry(:key, :value) in _boards.entries)
          key.name: value.toJson(),
      },
      'personalization': _personalization.toJson(),
      // Every widget these boards have had the chance to show.
      'introduced': BoardIds.introduced.keys.toList(),
    };
    return _enqueue(
      () => _repo.saveDocument(_settingsKey, json),
      key: _settingsKey,
    );
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  static int _dayKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;
}
