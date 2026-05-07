enum CongestionLevel { none, mild, heavy }

extension CongestionLevelLabel on CongestionLevel {
  String get label {
    switch (this) {
      case CongestionLevel.none:
        return 'Clear';
      case CongestionLevel.mild:
        return 'Mild traffic';
      case CongestionLevel.heavy:
        return 'Heavy traffic';
    }
  }
}

class TrafficEvent {
  final double latitude;
  final double longitude;
  final CongestionLevel level;
  final int stationaryUsers;
  final double averageSpeedKmph;
  final DateTime startedAt;
  final DateTime updatedAt;

  const TrafficEvent({
    required this.latitude,
    required this.longitude,
    required this.level,
    required this.stationaryUsers,
    required this.averageSpeedKmph,
    required this.startedAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'level': level.name,
      'stationaryUsers': stationaryUsers,
      'averageSpeedKmph': averageSpeedKmph,
      'startedAt': startedAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory TrafficEvent.fromMap(Map<dynamic, dynamic> map) {
    return TrafficEvent(
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
      level: CongestionLevel.values.firstWhere(
        (level) => level.name == map['level'],
        orElse: () => CongestionLevel.none,
      ),
      stationaryUsers: (map['stationaryUsers'] as num?)?.toInt() ?? 0,
      averageSpeedKmph: (map['averageSpeedKmph'] as num?)?.toDouble() ?? 0,
      startedAt:
          DateTime.tryParse(map['startedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          DateTime.tryParse(map['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
