import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import './trip_model.dart';
import '../storage/local_db.dart';

class TripDetectionModule {
  final LocalDB db = LocalDB();

  bool tripActive = false;

  Position? lastPosition;
  double distanceTravelled = 0;

  DateTime? startCandidateTime;
  DateTime? stopCandidateTime;
  Position? stopCenter;

  DateTime? tripStartTime;
  String startLocation = "Unknown";

  void processLocation(Position position) {
    double speedKmph = position.speed * 3.6;
    DateTime now = DateTime.now();

    // ---------- DISTANCE CALC ----------
    if (lastPosition != null) {
      double d = Geolocator.distanceBetween(
        lastPosition!.latitude,
        lastPosition!.longitude,
        position.latitude,
        position.longitude,
      );

      if (d > 5) {
        distanceTravelled += d;
      }
    }

    lastPosition = position;

    debugPrint("Speed: ${speedKmph.toStringAsFixed(2)} km/h");
    debugPrint("Distance: ${distanceTravelled.toStringAsFixed(1)} m");

    // ---------- TRIP START ----------
    if (!tripActive && speedKmph > 8 && distanceTravelled > 100) {
      startCandidateTime ??= now;

      if (now.difference(startCandidateTime!).inSeconds >= 30) {
        tripActive = true;
        tripStartTime = now;
        startLocation = "Lat: ${position.latitude}, Lng: ${position.longitude}";

        debugPrint("Trip STARTED");
      }
    } else {
      startCandidateTime = null;
    }
    if (!tripActive && speedKmph < 2) {
      distanceTravelled = 0;
    }

    // ---------- TRIP END ----------
    if (tripActive && speedKmph < 1) {
      stopCandidateTime ??= now;
      stopCenter ??= position;

      double stopDistance = Geolocator.distanceBetween(
        stopCenter!.latitude,
        stopCenter!.longitude,
        position.latitude,
        position.longitude,
      );

      if (stopDistance > 30) {
        stopCandidateTime = null;
        stopCenter = null;
      }
      if (tripStartTime == null) return;

      if (stopCandidateTime != null &&
          now.difference(stopCandidateTime!).inMinutes >= 2) {
        DateTime tripEndTime = now;
        Duration tripDuration = tripEndTime.difference(tripStartTime!);

        String endLocation =
            "Lat: ${position.latitude}, Lng: ${position.longitude}";

        // 🔥 Create Trip object
        Trip trip = Trip(
          startLocation: startLocation,
          endLocation: endLocation,
          distance: distanceTravelled,
          duration: tripDuration,
          startTime: tripStartTime!,
          endTime: tripEndTime,
        );

        // 🔥 Print full trip details
        debugPrint(trip.toString());

        db.saveTrip(trip);

        debugPrint("Trip ENDED");

        // Reset
        tripActive = false;
        distanceTravelled = 0;
        stopCandidateTime = null;
        stopCenter = null;
        tripStartTime = null;
      }
    } else {
      stopCandidateTime = null;
    }
  }
}
