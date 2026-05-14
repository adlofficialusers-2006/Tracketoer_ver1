import 'package:hive/hive.dart';

import '../traffic/movement_log.dart';
import '../traffic/traffic_event.dart';
import '../trip/trip_model.dart';

class LocalDB {
  static const tripsBox = 'trips';
  static const movementLogsBox = 'movement_logs';
  static const trafficEventsBox = 'traffic_events';
  static const settingsBoxName = 'settings';
  static const usersBoxName = 'users';
  static const serverTripsBoxName = 'server_trips';

  final Box<dynamic> box = Hive.box(tripsBox);
  final Box<dynamic> movementBox = Hive.box(movementLogsBox);
  final Box<dynamic> trafficBox = Hive.box(trafficEventsBox);
  final Box<dynamic> settingsBox = Hive.box(settingsBoxName);
  final Box<dynamic> usersBox = Hive.box(usersBoxName);
  final Box<dynamic> serverTripsBox = Hive.box(serverTripsBoxName);

  static Future<void> openBoxes() async {
    if (!Hive.isBoxOpen(tripsBox))         await Hive.openBox(tripsBox);
    if (!Hive.isBoxOpen(movementLogsBox))  await Hive.openBox(movementLogsBox);
    if (!Hive.isBoxOpen(trafficEventsBox)) await Hive.openBox(trafficEventsBox);
    if (!Hive.isBoxOpen(settingsBoxName))  await Hive.openBox(settingsBoxName);
    if (!Hive.isBoxOpen(usersBoxName))     await Hive.openBox(usersBoxName);
    if (!Hive.isBoxOpen(serverTripsBoxName)) await Hive.openBox(serverTripsBoxName);
  }

  // ── Settings helpers ──────────────────────────────────────────────────────

  void setSetting(String key, dynamic value) => settingsBox.put(key, value);

  T? getSetting<T>(String key) => settingsBox.get(key) as T?;

  bool get hasLocationConsent =>
      settingsBox.get('location_consent_given') == true;

  void setLocationConsent(bool value) =>
      settingsBox.put('location_consent_given', value);

  /// The userId of whoever is currently logged in. Falls back to empty string.
  String get currentUserId =>
      settingsBox.get('currentUserId') as String? ?? '';

  // ── Trip storage ──────────────────────────────────────────────────────────

  Future<dynamic> saveTrip(Trip trip) async {
    final tripMap = trip.toMap();
    tripMap['tripNumber'] = box.length + 1;
    tripMap['synced'] = false;
    // Attach current user so admin can filter by owner later.
    if (tripMap['userId'] == null || (tripMap['userId'] as String).isEmpty) {
      tripMap['userId'] = currentUserId;
    }
    return box.add(tripMap);
  }

  void saveMovementLog(MovementLog log) {
    movementBox.add(log.toMap());
  }

  void saveTrafficEvent(TrafficEvent event) {
    trafficBox.add(event.toMap());
  }

  List getTrips() {
    return box.values.toList();
  }

  /// Returns trips with their Hive keys. Pass [userId] to filter by owner.
  List<Map<String, dynamic>> getTripsWithKeys({String? userId}) {
    return box.keys
        .map((key) {
          final value = box.get(key);
          if (value is! Map) return null;
          final trip = Map<String, dynamic>.from(value);
          trip['key'] = key;
          return trip;
        })
        .whereType<Map<String, dynamic>>()
        .where((trip) {
          if (userId == null || userId.isEmpty) return true;
          return (trip['userId'] as String? ?? '') == userId;
        })
        .toList();
  }

  void updateTrip(dynamic key, Map<String, dynamic> updates) {
    final existing = box.get(key);
    if (existing is! Map) return;
    final trip = Map<String, dynamic>.from(existing);
    trip.addAll(updates);
    box.put(key, trip);
  }

  void markAsSynced(dynamic key) {
    updateTrip(key, {'synced': true});
  }

  // ── Movement / traffic ────────────────────────────────────────────────────

  List<MovementLog> getRecentMovementLogs({
    Duration window = const Duration(minutes: 3),
  }) {
    final cutoff = DateTime.now().subtract(window);
    return movementBox.values
        .whereType<Map>()
        .map(MovementLog.fromMap)
        .where((log) => log.timestamp.isAfter(cutoff))
        .toList();
  }

  List<TrafficEvent> getTrafficEvents() {
    return trafficBox.values
        .whereType<Map>()
        .map(TrafficEvent.fromMap)
        .toList();
  }

  // ── Server-fetched trips (admin view) ─────────────────────────────────────

  /// Replaces cached server trips with a fresh download.
  void cacheServerTrips(List<Map<String, dynamic>> trips) {
    serverTripsBox.clear();
    for (final trip in trips) {
      serverTripsBox.add(trip);
    }
  }

  /// Returns all trips cached from the backend server.
  List<Map<String, dynamic>> getServerTrips() {
    return serverTripsBox.values
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }

  bool get hasServerTrips => serverTripsBox.isNotEmpty;
}
