import 'dart:ui' show Color;

import 'package:health_app/notifications/notifier.dart';
import 'package:health_app/notifications/reminder_plan.dart';

/// Records what would have been shown or scheduled.
class FakeNotifier implements Notifier {
  bool allow = true;
  List<PlannedReminder> scheduled = [];
  List<PlannedReminder> medications = [];
  final List<String> shown = [];
  Duration? rest;
  bool ongoing = false;

  @override
  Future<void> init() async {}

  String? picture;

  @override
  void useIcon(Color? color, String? picture) => this.picture = picture;

  int permissionRequests = 0;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return allow;
  }

  @override
  Future<void> replaceReminders(List<PlannedReminder> plan) async =>
      scheduled = plan;

  /// Makes scheduling medication reminders fail.
  bool failMedications = false;

  @override
  Future<void> replaceMedicationReminders(List<PlannedReminder> plan) async {
    if (failMedications) throw Exception('scheduling failed');
    medications = plan;
  }

  @override
  Future<void> showRestTimer(Duration rest) async => this.rest = rest;

  @override
  Future<void> cancelRestTimer() async => rest = null;

  @override
  Future<void> showWorkoutOngoing(
    String title,
    DateTime startedAt, {
    bool paused = false,
  }) async => ongoing = true;

  @override
  Future<void> cancelWorkoutOngoing() async => ongoing = false;

  @override
  Future<void> showMessage(String title, String body) async => shown.add(title);

  /// Single notifications by id: when (or daily time) and title.
  final Map<int, (Object when, String title)> single = {};

  @override
  Future<void> scheduleOnce(
    int id,
    DateTime at,
    String title,
    String body,
  ) async => single[id] = (at, title);

  @override
  Future<void> scheduleDaily(
    int id,
    ({int hour, int minute}) time,
    String title,
    String body,
  ) async => single[id] = (time, title);

  @override
  Future<void> cancel(int id) async {
    single.remove(id);
    if (id == NotificationIds.fastingLive) fastingEnd = null;
  }

  /// The habits notification: today's habits and those left; null once
  /// cleared.
  ({List<String> all, List<String> left})? habits;

  @override
  Future<void> showHabits(
    DateTime day,
    List<String> all,
    List<String> left,
  ) async =>
      habits = all.isEmpty || left.isEmpty ? null : (all: all, left: left);

  DateTime? fastingEnd;

  @override
  Future<void> showFasting(DateTime end) async => fastingEnd = end;
}
