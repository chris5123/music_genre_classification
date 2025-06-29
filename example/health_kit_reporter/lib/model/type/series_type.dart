/// Equivalent of [SeriesType]
/// from [HealthKitReporter] https://cocoapods.org/pods/HealthKitReporter
///
/// Supports [identifier] extension representing
/// original [String] of the type.
///
enum SeriesType {
  heartbeatSeries,
  workoutRoute,
}

extension SeriesTypeIdentifier on SeriesType {
  String get identifier {
    switch (this) {
      case SeriesType.heartbeatSeries:
        return 'HKDataTypeIdentifierHeartbeatSeries';
      case SeriesType.workoutRoute:
        return 'HKWorkoutRouteTypeIdentifier';
    }
  }
}
