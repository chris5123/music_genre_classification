/// Equivalent of [PreferredUnit]
/// from [HealthKitReporter] https://cocoapods.org/pods/HealthKitReporter
///
/// Has a [PreferredUnit.fromJson] constructor
/// to create instances from JSON payload coming from iOS native code.
///
class PreferredUnit {
  const PreferredUnit(
    this.identifier,
    this.unit,
  );

  final String identifier;
  final String unit;

  /// General map representation
  ///
  Map<String, String> get map => {
        'identifier': identifier,
        'unit': unit,
      };

  /// General constructor from JSON payload
  ///
  PreferredUnit.fromJson(Map<String, dynamic> json)
      : identifier = json['identifier'],
        unit = json['unit'];
}
