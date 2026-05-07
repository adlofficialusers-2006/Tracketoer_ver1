import 'package:flutter_test/flutter_test.dart';
import 'package:govt_tracker_version_1/modules/trip/trip_model.dart';

void main() {
  test('trip serializes duration correction fields', () {
    final startedAt = DateTime(2026, 5, 6, 9);
    final endedAt = DateTime(2026, 5, 6, 10);

    final trip = Trip(
      startLocation: '10.0, 76.0',
      endLocation: '10.1, 76.1',
      distance: 4200,
      duration: const Duration(minutes: 54),
      startTime: startedAt,
      endTime: endedAt,
      pausedDuration: const Duration(minutes: 6),
      trafficDelayDuration: const Duration(minutes: 12),
    );

    final restored = Trip.fromMap(trip.toMap());

    expect(restored.distance, 4200);
    expect(restored.duration, const Duration(minutes: 54));
    expect(restored.pausedDuration, const Duration(minutes: 6));
    expect(restored.trafficDelayDuration, const Duration(minutes: 12));
  });
}
