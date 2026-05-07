import 'package:hive/hive.dart';
import '../trip/trip_model.dart';
import '../traffic/movement_log.dart';
import '../traffic/traffic_event.dart';

class LocalDB {
  static const tripsBox = 'trips';
  static const movementLogsBox = 'movement_logs';
  static const trafficEventsBox = 'traffic_events';

  final Box<dynamic> box = Hive.box(tripsBox);
  final Box<dynamic> movementBox = Hive.box(movementLogsBox);
  final Box<dynamic> trafficBox = Hive.box(trafficEventsBox);

  static Future<void> openBoxes() async {
    await Hive.openBox(tripsBox);
    await Hive.openBox(movementLogsBox);
    await Hive.openBox(trafficEventsBox);
  }

  void saveTrip(Trip trip) {
    final tripMap = trip.toMap();
    tripMap['tripNumber'] = box.length + 1;
    tripMap['synced'] = false;
    box.add(tripMap);
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

  List<Map<String, dynamic>> getTripsWithKeys() {
    return box.keys.map((key) {
      final value = box.get(key);
      final trip = Map<String, dynamic>.from(value as Map);
      trip['key'] = key;
      return trip;
    }).toList();
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
}
