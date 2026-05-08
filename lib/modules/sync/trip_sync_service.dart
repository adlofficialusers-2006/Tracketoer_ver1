import 'dart:convert';
import 'dart:io';

import '../storage/local_db.dart';

class TripSyncService {
  TripSyncService({
    LocalDB? db,
    this.endpoint = const String.fromEnvironment('NATPAC_SYNC_ENDPOINT'),
  }) : db = db ?? LocalDB();

  final LocalDB db;
  final String endpoint;

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

  Future<int> uploadPendingTrips() async {
    if (endpoint.isEmpty) return 0;

    final uri = Uri.parse(endpoint);
    final pendingTrips = db.getTripsWithKeys()
      ..removeWhere((trip) => trip['synced'] == true);
    var uploaded = 0;

    for (final trip in pendingTrips) {
      final key = trip.remove('key');
      final client = HttpClient();
      try {
        final request = await client.postUrl(uri);
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(trip));
        final response = await request.close();
        if (response.statusCode >= 200 && response.statusCode < 300) {
          db.markAsSynced(key);
          uploaded += 1;
        }
      } finally {
        client.close(force: true);
      }
    }

    return uploaded;
  }
}
