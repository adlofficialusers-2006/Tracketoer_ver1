import 'traffic_event.dart';

class TravelTimeEstimate {
  final Duration baseDuration;
  final Duration expectedDelay;
  final Duration totalDuration;
  final CongestionLevel congestionLevel;

  const TravelTimeEstimate({
    required this.baseDuration,
    required this.expectedDelay,
    required this.totalDuration,
    required this.congestionLevel,
  });
}

class TravelTimeEstimator {
  const TravelTimeEstimator();

  TravelTimeEstimate estimate({
    required double segmentDistanceMeters,
    required double historicalAverageKmph,
    required double liveAverageKmph,
    required CongestionLevel level,
  }) {
    final safeHistoricalSpeed = historicalAverageKmph.clamp(5, 120);
    final safeLiveSpeed = liveAverageKmph.clamp(2, 120);

    final baseHours = segmentDistanceMeters / 1000 / safeHistoricalSpeed;
    final liveHours = segmentDistanceMeters / 1000 / safeLiveSpeed;
    final baseDuration = Duration(seconds: (baseHours * 3600).round());
    final liveDuration = Duration(seconds: (liveHours * 3600).round());
    final delay = liveDuration - baseDuration;

    return TravelTimeEstimate(
      baseDuration: baseDuration,
      expectedDelay: delay.isNegative ? Duration.zero : delay,
      totalDuration: liveDuration,
      congestionLevel: level,
    );
  }
}
