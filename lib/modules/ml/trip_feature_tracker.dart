import 'dart:math';

class TripFeatureSnapshot {
  const TripFeatureSnapshot({
    required this.avgSpeedKmph,
    required this.idleRatio,
    required this.accelerationVariance,
    required this.avgStopDurationSec,
    required this.stopFrequencyPerHr,
  });

  final double avgSpeedKmph;
  final double idleRatio;
  final double accelerationVariance;
  final double avgStopDurationSec;
  final double stopFrequencyPerHr;

  Map<String, double> toModelInput() {
    return {
      'avg_speed_kmph': avgSpeedKmph,
      'idle_ratio': idleRatio,
      'acceleration_variance': accelerationVariance,
      'avg_stop_duration_sec': avgStopDurationSec,
      'stop_frequency_per_hr': stopFrequencyPerHr,
    };
  }
}

class TripFeatureTracker {
  TripFeatureTracker({this.stationarySpeedKmph = 1.5});

  final double stationarySpeedKmph;

  DateTime? _lastSampleAt;
  double? _lastSpeedKmph;
  DateTime? _currentStopStartedAt;

  double _sampleSpeedTotal = 0;
  int _sampleCount = 0;
  double _idleSeconds = 0;
  final List<double> _stopDurationsSec = [];
  final List<double> _accelerations = [];

  void reset() {
    _lastSampleAt = null;
    _lastSpeedKmph = null;
    _currentStopStartedAt = null;
    _sampleSpeedTotal = 0;
    _sampleCount = 0;
    _idleSeconds = 0;
    _stopDurationsSec.clear();
    _accelerations.clear();
  }

  void addSample({
    required DateTime timestamp,
    required double speedKmph,
  }) {
    final safeSpeed = speedKmph.clamp(0, 220).toDouble();
    final lastAt = _lastSampleAt;
    final lastSpeed = _lastSpeedKmph;

    if (lastAt != null && lastSpeed != null) {
      final deltaSeconds = max(
        0,
        timestamp.difference(lastAt).inMilliseconds / 1000,
      ).toDouble();

      if (deltaSeconds > 0 && deltaSeconds <= 120) {
        if (lastSpeed < stationarySpeedKmph) {
          _idleSeconds += deltaSeconds;
        }

        final speedDeltaMetersPerSecond = (safeSpeed - lastSpeed) / 3.6;
        _accelerations.add(speedDeltaMetersPerSecond / deltaSeconds);
      }
    }

    if (safeSpeed < stationarySpeedKmph) {
      _currentStopStartedAt ??= timestamp;
    } else {
      _closeStop(timestamp);
    }

    _sampleSpeedTotal += safeSpeed;
    _sampleCount += 1;
    _lastSampleAt = timestamp;
    _lastSpeedKmph = safeSpeed;
  }

  TripFeatureSnapshot snapshot({
    required Duration tripDuration,
    required double distanceMeters,
    DateTime? now,
  }) {
    final endedAt = now ?? DateTime.now();
    final stopDurations = List<double>.from(_stopDurationsSec);
    final activeStopStartedAt = _currentStopStartedAt;
    if (activeStopStartedAt != null) {
      final activeStopDuration =
          endedAt.difference(activeStopStartedAt).inMilliseconds / 1000;
      if (activeStopDuration >= 3) {
        stopDurations.add(activeStopDuration.toDouble());
      }
    }

    final durationSeconds = max(1, tripDuration.inSeconds).toDouble();
    final distanceSpeedKmph = (distanceMeters / durationSeconds) * 3.6;
    final sampledSpeedKmph =
        _sampleCount == 0 ? 0 : _sampleSpeedTotal / _sampleCount;
    final avgSpeedKmph = distanceMeters > 30 ? distanceSpeedKmph : sampledSpeedKmph;

    final avgStopDuration = stopDurations.isEmpty
        ? 0.0
        : stopDurations.reduce((a, b) => a + b) / stopDurations.length;
    final stopFrequencyPerHr = stopDurations.length / (durationSeconds / 3600);

    return TripFeatureSnapshot(
      avgSpeedKmph: avgSpeedKmph.clamp(0, 220).toDouble(),
      idleRatio: (_idleSeconds / durationSeconds).clamp(0, 1).toDouble(),
      accelerationVariance: _variance(_accelerations),
      avgStopDurationSec: avgStopDuration,
      stopFrequencyPerHr: stopFrequencyPerHr.isFinite ? stopFrequencyPerHr : 0,
    );
  }

  void _closeStop(DateTime timestamp) {
    final startedAt = _currentStopStartedAt;
    if (startedAt == null) return;

    final duration = timestamp.difference(startedAt).inMilliseconds / 1000;
    if (duration >= 3) {
      _stopDurationsSec.add(duration.toDouble());
    }
    _currentStopStartedAt = null;
  }

  double _variance(List<double> values) {
    if (values.length < 2) return 0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final total = values
        .map((value) => pow(value - mean, 2).toDouble())
        .reduce((a, b) => a + b);
    return total / (values.length - 1);
  }
}
