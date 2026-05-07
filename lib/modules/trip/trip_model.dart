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
  final Duration pausedDuration;
  final Duration trafficDelayDuration;
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
    this.pausedDuration = Duration.zero,
    this.trafficDelayDuration = Duration.zero,
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
      'pausedDuration': pausedDuration.inSeconds,
      'trafficDelayDuration': trafficDelayDuration.inSeconds,
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
      pausedDuration: Duration(
        seconds: (map['pausedDuration'] as num?)?.toInt() ?? 0,
      ),
      trafficDelayDuration: Duration(
        seconds: (map['trafficDelayDuration'] as num?)?.toInt() ?? 0,
      ),
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
Mode: $mode
Purpose: $purpose
Cost: $cost
Companions: $companions
Frequency: $frequency
''';
  }
}
