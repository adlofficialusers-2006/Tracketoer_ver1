import '../storage/local_db.dart';

class TripSyncService {
  final LocalDB db = LocalDB();

  Future<List<Map<String, dynamic>>> fetchAllTrips() async {
    final trips = db.getTrips();
    return trips.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchPendingTrips() async {
    final trips = db.getTrips();
    return trips
        .where((trip) => trip is Map<String, dynamic> && trip['synced'] != true)
        .cast<Map<String, dynamic>>()
        .toList();
  }

  Future<void> markAsSynced(int key) async {
    db.markAsSynced(key);
  }
}
