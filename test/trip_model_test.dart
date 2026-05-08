import 'package:flutter_test/flutter_test.dart';
import 'package:govt_tracker_version_1/modules/ml/transport_mode_predictor.dart';
import 'package:govt_tracker_version_1/modules/ml/trip_feature_tracker.dart';
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

  test('trip serializes mode prediction and movement metrics', () {
    final trip = Trip(
      startLocation: '10.0, 76.0',
      endLocation: '10.1, 76.1',
      distance: 4200,
      duration: const Duration(minutes: 20),
      startTime: DateTime(2026, 5, 6, 9),
      endTime: DateTime(2026, 5, 6, 9, 20),
      startLatitude: 10,
      startLongitude: 76,
      endLatitude: 10.1,
      endLongitude: 76.1,
      avgSpeedKmph: 32,
      idleRatio: 0.12,
      accelerationVariance: 1.4,
      avgStopDurationSec: 18,
      stopFrequencyPerHr: 4,
      mode: 'Car',
      modeConfidence: 0.82,
      modeSource: 'ml',
    );

    final restored = Trip.fromMap(trip.toMap());

    expect(restored.startLatitude, 10);
    expect(restored.endLongitude, 76.1);
    expect(restored.avgSpeedKmph, 32);
    expect(restored.mode, 'Car');
    expect(restored.modeConfidence, 0.82);
    expect(restored.modeSource, 'ml');
  });

  test('feature tracker calculates stop and idle features', () {
    final tracker = TripFeatureTracker();
    final start = DateTime(2026, 5, 6, 9);

    tracker.addSample(timestamp: start, speedKmph: 0);
    tracker.addSample(
      timestamp: start.add(const Duration(seconds: 10)),
      speedKmph: 0,
    );
    tracker.addSample(
      timestamp: start.add(const Duration(seconds: 20)),
      speedKmph: 30,
    );

    final snapshot = tracker.snapshot(
      tripDuration: const Duration(seconds: 20),
      distanceMeters: 120,
      now: start.add(const Duration(seconds: 20)),
    );

    expect(snapshot.avgSpeedKmph, closeTo(21.6, 0.01));
    expect(snapshot.idleRatio, closeTo(1, 0.01));
    expect(snapshot.avgStopDurationSec, closeTo(20, 0.01));
    expect(snapshot.stopFrequencyPerHr, closeTo(180, 0.01));
  });

  test('transport mode predictor evaluates exported XGBoost trees', () {
    final predictor = TransportModePredictor.fromJson({
      'modelType': 'xgboost_classifier',
      'features': [
        'avg_speed_kmph',
        'idle_ratio',
        'acceleration_variance',
        'avg_stop_duration_sec',
        'stop_frequency_per_hr',
      ],
      'classes': ['car', 'bus'],
      'imputation': {
        'values': {
          'avg_speed_kmph': 30,
          'idle_ratio': 0,
          'acceleration_variance': 0,
          'avg_stop_duration_sec': 0,
          'stop_frequency_per_hr': 0,
        },
      },
      'xgboost': {
        'baseScore': 0,
        'trees': [
          {
            'classIndex': 0,
            'tree': {
              'nodeid': 0,
              'split': 'avg_speed_kmph',
              'split_condition': 40,
              'yes': 1,
              'no': 2,
              'children': [
                {'nodeid': 1, 'leaf': 1.25},
                {'nodeid': 2, 'leaf': -1.25},
              ],
            },
          },
          {
            'classIndex': 1,
            'tree': {'nodeid': 0, 'leaf': 0},
          },
        ],
      },
    });

    final prediction = predictor.predict(
      const TripFeatureSnapshot(
        avgSpeedKmph: 20,
        idleRatio: 0.1,
        accelerationVariance: 1,
        avgStopDurationSec: 5,
        stopFrequencyPerHr: 2,
      ),
    );

    expect(prediction.label, 'car');
    expect(prediction.confidence, greaterThan(0.5));
  });
}
