class MovementLog {
  final String deviceId;
  final double latitude;
  final double longitude;
  final double speedKmph;
  final DateTime timestamp;

  const MovementLog({
    required this.deviceId,
    required this.latitude,
    required this.longitude,
    required this.speedKmph,
    required this.timestamp,
  });

  bool get isStationary => speedKmph < 2;

  Map<String, dynamic> toMap() {
    return {
      'deviceId': deviceId,
      'latitude': latitude,
      'longitude': longitude,
      'speedKmph': speedKmph,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory MovementLog.fromMap(Map<dynamic, dynamic> map) {
    return MovementLog(
      deviceId: map['deviceId'] as String? ?? 'unknown',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
      speedKmph: (map['speedKmph'] as num?)?.toDouble() ?? 0,
      timestamp:
          DateTime.tryParse(map['timestamp'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
