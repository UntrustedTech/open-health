import 'package:flutter_test/flutter_test.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/screens/metric_detail_screen.dart';

void main() {
  test("today's unfinished steps don't count toward lowest and average", () {
    final s = rangeStats(MetricType.steps, [8000, 6000, 10000, 4])!;
    expect(s.min, 6000);
    expect(s.average, 8000);
  });

  test("today's steps count when they're all there is", () {
    expect(rangeStats(MetricType.steps, [null, null, 4])!.min, 4);
  });

  test('last night counts for sleep, and averages keep today', () {
    expect(rangeStats(MetricType.sleep, [7, 8, 6])!.min, 6);
    expect(rangeStats(MetricType.heartRate, [70, 80, 60])!.min, 60);
  });
}
