import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../location/location_tracking_module.dart';
import '../storage/local_db.dart';
import '../traffic/crowd_detection_service.dart';
import '../traffic/movement_log.dart';
import './trip_model.dart';

class TripLifecycleController extends ChangeNotifier {
  TripLifecycleController({
    required this.locationModule,
    required this.db,
    required this.crowdDetectionService,
    this.deviceId = 'local-device',
  });

  final LocationTrackingModule locationModule;
  final LocalDB db;
  final CrowdDetectionService crowdDetectionService;
  final String deviceId;

  static const double startSpeedThresholdKmph = 5;
  static const double stationarySpeedThresholdKmph = 1.5;
  static const double stopRadiusMeters = 35;
  static const Duration startConsistencyDuration = Duration(seconds: 20);
  static const Duration stagnationDuration = Duration(minutes: 2);

  StreamSubscription<Position>? _positionSubscription;
  Position? _lastPosition;
  Position? _stopCenter;
  DateTime? _startCandidateAt;
  DateTime? _stopCandidateAt;
  DateTime? _tripStartAt;
  DateTime? _pauseStartedAt;
  DateTime? _lastTrafficDelayAt;
  String _startLocation = 'Unknown';

  TripStatus _status = TripStatus.idle;
  double _distanceMeters = 0;
  double _currentSpeedKmph = 0;
  Duration _pausedDuration = Duration.zero;
  Duration _trafficDelayDuration = Duration.zero;
  Position? _currentPosition;
  bool _needsStopConfirmation = false;
  CrowdDetectionResult _crowdResult = CrowdDetectionResult.clear;

  TripStatus get status => _status;
  double get distanceMeters => _distanceMeters;
  double get currentSpeedKmph => _currentSpeedKmph;
  Position? get currentPosition => _currentPosition;
  bool get needsStopConfirmation => _needsStopConfirmation;
  CrowdDetectionResult get crowdResult => _crowdResult;

  bool get hasActiveTrip =>
      _tripStartAt != null &&
      _status != TripStatus.idle &&
      _status != TripStatus.moving;

  Duration get elapsedDuration {
    final startedAt = _tripStartAt;
    if (startedAt == null) return Duration.zero;

    final now = DateTime.now();
    final activePause = _pauseStartedAt == null
        ? Duration.zero
        : now.difference(_pauseStartedAt!);

    return now.difference(startedAt) - _pausedDuration - activePause;
  }

  Future<void> start() async {
    final stream = await locationModule.startTracking();
    if (stream == null) {
      _status = TripStatus.idle;
      notifyListeners();
      return;
    }

    _positionSubscription?.cancel();
    _positionSubscription = stream.listen(processLocation);
  }

  void processLocation(Position position) {
    final now = DateTime.now();
    _currentPosition = position;
    _currentSpeedKmph = (position.speed * 3.6).clamp(0, 220);

    _saveMovementPing(position, now);
    _updateDistance(position);
    _lastPosition = position;

    if (_tripStartAt == null) {
      _evaluateAutoStart(position, now);
    } else {
      _evaluateActiveTrip(position, now);
    }

    notifyListeners();
  }

  void manualStart() {
    final position = _currentPosition;
    if (position == null || _tripStartAt != null) return;
    _beginTrip(position, DateTime.now());
    notifyListeners();
  }

  void manualEnd() {
    final position = _currentPosition;
    if (position == null || _tripStartAt == null) return;
    _endTrip(position, DateTime.now());
    notifyListeners();
  }

  void confirmTripEnded() {
    final position = _currentPosition;
    if (position == null || _tripStartAt == null) return;
    _endTrip(position, DateTime.now());
    notifyListeners();
  }

  void resumeTrip() {
    _commitActivePause();
    _needsStopConfirmation = false;
    _stopCandidateAt = null;
    _stopCenter = null;
    _status = TripStatus.active;
    notifyListeners();
  }

  void _evaluateAutoStart(Position position, DateTime now) {
    if (_currentSpeedKmph > startSpeedThresholdKmph) {
      _startCandidateAt ??= now;
      _status = TripStatus.moving;

      final hasConsistentMovement =
          now.difference(_startCandidateAt!) >= startConsistencyDuration;
      if (hasConsistentMovement && _distanceMeters >= 30) {
        _beginTrip(position, now);
      }
      return;
    }

    _status = TripStatus.idle;
    _startCandidateAt = null;
    if (_currentSpeedKmph < 2) _distanceMeters = 0;
  }

  void _evaluateActiveTrip(Position position, DateTime now) {
    if (_currentSpeedKmph > stationarySpeedThresholdKmph) {
      if (_lastTrafficDelayAt != null) {
        _trafficDelayDuration += now.difference(_lastTrafficDelayAt!);
        _lastTrafficDelayAt = null;
      }
      if (_status == TripStatus.potentialStop || _status == TripStatus.paused) {
        _commitActivePause();
      }
      _status = TripStatus.active;
      _needsStopConfirmation = false;
      _stopCandidateAt = null;
      _stopCenter = null;
      return;
    }

    _stopCandidateAt ??= now;
    _stopCenter ??= position;

    final driftMeters = Geolocator.distanceBetween(
      _stopCenter!.latitude,
      _stopCenter!.longitude,
      position.latitude,
      position.longitude,
    );

    if (driftMeters > stopRadiusMeters) {
      _stopCandidateAt = now;
      _stopCenter = position;
      return;
    }

    final stagnantLongEnough =
        now.difference(_stopCandidateAt!) >= stagnationDuration;
    if (!stagnantLongEnough) return;

    _crowdResult = crowdDetectionService.classifyNearbyCrowd(
      latitude: position.latitude,
      longitude: position.longitude,
    );

    if (_crowdResult.isTraffic) {
      _commitActivePause();
      _markTrafficDelay(position, now);
      return;
    }

    _status = TripStatus.potentialStop;
    _needsStopConfirmation = true;
    _pauseStartedAt ??= now;
  }

  void _beginTrip(Position position, DateTime now) {
    _tripStartAt = now;
    _startLocation = _formatPosition(position);
    _status = TripStatus.active;
    _distanceMeters = 0;
    _pausedDuration = Duration.zero;
    _trafficDelayDuration = Duration.zero;
    _needsStopConfirmation = false;
    _startCandidateAt = null;
    _stopCandidateAt = null;
    _stopCenter = null;
    _pauseStartedAt = null;
  }

  void _endTrip(Position position, DateTime now) {
    _commitActivePause();
    final startedAt = _tripStartAt;
    if (startedAt == null) return;

    final trip = Trip(
      startLocation: _startLocation,
      endLocation: _formatPosition(position),
      distance: _distanceMeters,
      duration: now.difference(startedAt) - _pausedDuration,
      startTime: startedAt,
      endTime: now,
      pausedDuration: _pausedDuration,
      trafficDelayDuration: _trafficDelayDuration,
    );

    db.saveTrip(trip);
    _resetTripState();
  }

  void _updateDistance(Position position) {
    if (_lastPosition == null) return;
    if (_tripStartAt == null && _currentSpeedKmph < startSpeedThresholdKmph) {
      return;
    }
    if (_status == TripStatus.potentialStop || _status == TripStatus.paused) {
      return;
    }

    final distance = Geolocator.distanceBetween(
      _lastPosition!.latitude,
      _lastPosition!.longitude,
      position.latitude,
      position.longitude,
    );
    if (distance >= 3 && distance <= 200) {
      _distanceMeters += distance;
    }
  }

  void _markTrafficDelay(Position position, DateTime now) {
    _status = TripStatus.trafficDelay;
    _needsStopConfirmation = false;

    if (_lastTrafficDelayAt != null) {
      _trafficDelayDuration += now.difference(_lastTrafficDelayAt!);
    }
    _lastTrafficDelayAt = now;

    crowdDetectionService.persistTrafficEvent(
      latitude: position.latitude,
      longitude: position.longitude,
      result: _crowdResult,
    );
  }

  void _commitActivePause() {
    if (_pauseStartedAt == null) return;
    _pausedDuration += DateTime.now().difference(_pauseStartedAt!);
    _pauseStartedAt = null;
  }

  void _saveMovementPing(Position position, DateTime now) {
    crowdDetectionService.ingestDevicePing(
      MovementLog(
        deviceId: deviceId,
        latitude: position.latitude,
        longitude: position.longitude,
        speedKmph: _currentSpeedKmph,
        timestamp: now,
      ),
    );
  }

  String _formatPosition(Position position) {
    return '${position.latitude.toStringAsFixed(6)}, '
        '${position.longitude.toStringAsFixed(6)}';
  }

  void _resetTripState() {
    _status = TripStatus.idle;
    _tripStartAt = null;
    _stopCandidateAt = null;
    _stopCenter = null;
    _pauseStartedAt = null;
    _lastTrafficDelayAt = null;
    _needsStopConfirmation = false;
    _distanceMeters = 0;
    _pausedDuration = Duration.zero;
    _trafficDelayDuration = Duration.zero;
    _crowdResult = CrowdDetectionResult.clear;
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }
}
