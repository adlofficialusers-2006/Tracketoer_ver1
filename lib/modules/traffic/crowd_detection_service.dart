import 'package:geolocator/geolocator.dart';

import '../storage/local_db.dart';
import 'movement_log.dart';
import 'traffic_event.dart';

class CrowdDetectionResult {
  final bool isTraffic;
  final CongestionLevel level;
  final int stationaryUsers;
  final double averageSpeedKmph;

  const CrowdDetectionResult({
    required this.isTraffic,
    required this.level,
    required this.stationaryUsers,
    required this.averageSpeedKmph,
  });

  static const clear = CrowdDetectionResult(
    isTraffic: false,
    level: CongestionLevel.none,
    stationaryUsers: 0,
    averageSpeedKmph: 0,
  );
}

class CrowdDetectionService {
  CrowdDetectionService({
    required this.db,
    this.radiusMeters = 80,
    this.minimumStationaryUsers = 3,
  });

  final LocalDB db;
  final double radiusMeters;
  final int minimumStationaryUsers;

  CrowdDetectionResult classifyNearbyCrowd({
    required double latitude,
    required double longitude,
  }) {
    final nearby = db.getRecentMovementLogs().where((log) {
      final distance = Geolocator.distanceBetween(
        latitude,
        longitude,
        log.latitude,
        log.longitude,
      );
      return distance <= radiusMeters;
    }).toList();

    if (nearby.isEmpty) return CrowdDetectionResult.clear;

    final stationary = nearby.where((log) => log.isStationary).toList();
    final averageSpeed =
        nearby
            .map((log) => log.speedKmph)
            .fold<double>(0, (total, speed) => total + speed) /
        nearby.length;

    final isTraffic = stationary.length >= minimumStationaryUsers;
    final level = !isTraffic
        ? CongestionLevel.none
        : averageSpeed < 3
        ? CongestionLevel.heavy
        : CongestionLevel.mild;

    return CrowdDetectionResult(
      isTraffic: isTraffic,
      level: level,
      stationaryUsers: stationary.length,
      averageSpeedKmph: averageSpeed,
    );
  }

  void ingestDevicePing(MovementLog log) {
    db.saveMovementLog(log);
  }

  void persistTrafficEvent({
    required double latitude,
    required double longitude,
    required CrowdDetectionResult result,
  }) {
    if (!result.isTraffic) return;

    final now = DateTime.now();
    db.saveTrafficEvent(
      TrafficEvent(
        latitude: latitude,
        longitude: longitude,
        level: result.level,
        stationaryUsers: result.stationaryUsers,
        averageSpeedKmph: result.averageSpeedKmph,
        startedAt: now,
        updatedAt: now,
      ),
    );
  }
}
