enum TripStatus { idle, moving, active, paused, potentialStop, trafficDelay }

extension TripStatusLabel on TripStatus {
  String get label {
    switch (this) {
      case TripStatus.idle:
        return 'Idle';
      case TripStatus.moving:
        return 'Moving';
      case TripStatus.active:
        return 'Active Trip';
      case TripStatus.paused:
        return 'Paused';
      case TripStatus.potentialStop:
        return 'Potential Stop';
      case TripStatus.trafficDelay:
        return 'Traffic Delay';
    }
  }
}

class Trip {
  final String startLocation;
  final String endLocation;
  final double distance; // meters
  final Duration duration;
  final DateTime startTime;
  final DateTime endTime;
  final double? startLatitude;
  final double? startLongitude;
  final double? endLatitude;
  final double? endLongitude;
  final Duration pausedDuration;
  final Duration trafficDelayDuration;
  final double avgSpeedKmph;
  final double idleRatio;
  final double accelerationVariance;
  final double avgStopDurationSec;
  final double stopFrequencyPerHr;
  final double modeConfidence;
  final String modeSource;
  // userId links this trip to the logged-in user so the admin can filter by owner.
  final String userId;
  String mode;
  String purpose;
  String cost;
  String companions;
  String frequency;

  Trip({
    required this.startLocation,
    required this.endLocation,
    required this.distance,
    required this.duration,
    required this.startTime,
    required this.endTime,
    this.startLatitude,
    this.startLongitude,
    this.endLatitude,
    this.endLongitude,
    this.pausedDuration = Duration.zero,
    this.trafficDelayDuration = Duration.zero,
    this.avgSpeedKmph = 0,
    this.idleRatio = 0,
    this.accelerationVariance = 0,
    this.avgStopDurationSec = 0,
    this.stopFrequencyPerHr = 0,
    this.modeConfidence = 0,
    this.modeSource = 'manual',
    this.userId = '',
    this.mode = 'Unknown',
    this.purpose = 'Unknown',
    this.cost = '0',
    this.companions = '0',
    this.frequency = 'Unknown',
  });

  Map<String, dynamic> toMap() {
    return {
      'start': startLocation,
      'end': endLocation,
      'distance': distance,
      'duration': duration.inSeconds,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'startLatitude': startLatitude,
      'startLongitude': startLongitude,
      'endLatitude': endLatitude,
      'endLongitude': endLongitude,
      'pausedDuration': pausedDuration.inSeconds,
      'trafficDelayDuration': trafficDelayDuration.inSeconds,
      'avgSpeedKmph': avgSpeedKmph,
      'idleRatio': idleRatio,
      'accelerationVariance': accelerationVariance,
      'avgStopDurationSec': avgStopDurationSec,
      'stopFrequencyPerHr': stopFrequencyPerHr,
      'modeConfidence': modeConfidence,
      'modeSource': modeSource,
      'userId': userId,
      'mode': mode,
      'purpose': purpose,
      'cost': cost,
      'companions': companions,
      'frequency': frequency,
    };
  }

  factory Trip.fromMap(Map<dynamic, dynamic> map) {
    return Trip(
      startLocation: map['start'] as String? ?? 'Unknown',
      endLocation: map['end'] as String? ?? 'Unknown',
      distance: (map['distance'] as num?)?.toDouble() ?? 0,
      duration: Duration(seconds: (map['duration'] as num?)?.toInt() ?? 0),
      startTime:
          DateTime.tryParse(map['startTime'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      endTime:
          DateTime.tryParse(map['endTime'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      startLatitude: (map['startLatitude'] as num?)?.toDouble(),
      startLongitude: (map['startLongitude'] as num?)?.toDouble(),
      endLatitude: (map['endLatitude'] as num?)?.toDouble(),
      endLongitude: (map['endLongitude'] as num?)?.toDouble(),
      pausedDuration: Duration(
        seconds: (map['pausedDuration'] as num?)?.toInt() ?? 0,
      ),
      trafficDelayDuration: Duration(
        seconds: (map['trafficDelayDuration'] as num?)?.toInt() ?? 0,
      ),
      avgSpeedKmph: (map['avgSpeedKmph'] as num?)?.toDouble() ?? 0,
      idleRatio: (map['idleRatio'] as num?)?.toDouble() ?? 0,
      accelerationVariance:
          (map['accelerationVariance'] as num?)?.toDouble() ?? 0,
      avgStopDurationSec:
          (map['avgStopDurationSec'] as num?)?.toDouble() ?? 0,
      stopFrequencyPerHr:
          (map['stopFrequencyPerHr'] as num?)?.toDouble() ?? 0,
      modeConfidence: (map['modeConfidence'] as num?)?.toDouble() ?? 0,
      modeSource: map['modeSource'] as String? ?? 'manual',
      userId: map['userId'] as String? ?? '',
      mode: map['mode'] as String? ?? 'Unknown',
      purpose: map['purpose'] as String? ?? 'Unknown',
      cost: map['cost'] as String? ?? '0',
      companions: map['companions'] as String? ?? '0',
      frequency: map['frequency'] as String? ?? 'Unknown',
    );
  }

  @override
  String toString() {
    return '''
Trip:
Start: $startLocation
End: $endLocation
Distance: ${distance.toStringAsFixed(1)} m
Duration: ${duration.inSeconds} sec
Paused: ${pausedDuration.inSeconds} sec
Traffic delay: ${trafficDelayDuration.inSeconds} sec
Avg speed: ${avgSpeedKmph.toStringAsFixed(1)} km/h
Idle ratio: ${idleRatio.toStringAsFixed(2)}
Acceleration variance: ${accelerationVariance.toStringAsFixed(2)}
Avg stop: ${avgStopDurationSec.toStringAsFixed(1)} sec
Stops/hr: ${stopFrequencyPerHr.toStringAsFixed(1)}
Mode: $mode
Mode confidence: ${(modeConfidence * 100).toStringAsFixed(0)}%
Purpose: $purpose
Cost: $cost
Companions: $companions
Frequency: $frequency
''';
  }
}
