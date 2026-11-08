import 'package:flutter/foundation.dart';

import 'package:health_app/models/metric_type.dart';

/// One reading from the phone's health platform, already converted to the
/// app's units (e.g. km, ml, hours). Platform-neutral so the import logic can
/// be tested without Health Connect.
@immutable
class HealthSample {
  const HealthSample({
    required this.type,
    required this.value,
    required this.start,
    required this.end,
  });

  final MetricType type;
  final double value;
  final DateTime start;
  final DateTime end;
}
