import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/models/workout.dart';
import 'package:health_app/platform/live_activity.dart';
import 'package:health_app/workout/geo.dart';
import 'package:health_app/workout/workout_tracker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('health/live_activity');
  final calls = <MethodCall>[];
  var now = DateTime(2026, 10, 26, 8);

  WorkoutTracker tracker(WorkoutType type) =>
      WorkoutTracker(type: type, weightKg: 70, clock: () => now)..start();

  setUp(() {
    calls.clear();
    now = DateTime(2026, 10, 26, 8);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return true;
        });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('shows the time recorded and whether it is paused', () {
    final t = tracker(WorkoutType.strength);
    now = now.add(const Duration(seconds: 95));
    t.pause();

    expect(LiveActivity.stateOf(t), {
      'elapsed': 95,
      'paused': true,
      'detail': '',
    });
  });

  test('GPS workouts show their distance', () {
    final t = tracker(WorkoutType.run);
    expect(LiveActivity.stateOf(t)['detail'], '');
    t.addLocation(GeoPoint(lat: 51.5, lng: -0.1, time: now));
    now = now.add(const Duration(seconds: 30));
    t.addLocation(GeoPoint(lat: 51.5 + 120 / 111194.9, lng: -0.1, time: now));

    expect(LiveActivity.stateOf(t)['detail'], '0.12 km');
  });

  test('starts, updates and ends on iPhone', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final t = tracker(WorkoutType.run);

    expect(await LiveActivity.start(t), isTrue);
    await LiveActivity.update(t);
    await LiveActivity.end();

    expect(calls.map((c) => c.method), ['start', 'update', 'end']);
    final args = calls.first.arguments as Map<Object?, Object?>;
    expect(args['type'], 'run');
    expect(args['color'], WorkoutType.run.color.toARGB32());
  });

  test('does nothing on Android', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final t = tracker(WorkoutType.run);

    expect(await LiveActivity.start(t), isFalse);
    await LiveActivity.update(t);
    await LiveActivity.end();

    expect(calls, isEmpty);
  });
}
