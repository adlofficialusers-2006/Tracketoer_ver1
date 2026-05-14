import 'dart:convert';
import 'dart:io';

import '../storage/local_db.dart';

class TripSyncService {
  TripSyncService({
    LocalDB? db,
    this.endpoint = const String.fromEnvironment('NATPAC_SYNC_ENDPOINT'),
  }) : db = db ?? LocalDB();

  final LocalDB db;

  /// Base URL of the backend, e.g. "http://192.168.1.10:3000".
  /// Set at build time: flutter run --dart-define=NATPAC_SYNC_ENDPOINT=http://...
  final String endpoint;

  // ── Upload (user devices → server) ───────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchAllTrips() async {
    return db.getTrips().cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchPendingTrips() async {
    return db
        .getTrips()
        .where((t) => t is Map<String, dynamic> && t['synced'] != true)
        .cast<Map<String, dynamic>>()
        .toList();
  }

  Future<void> markAsSynced(int key) async {
    db.markAsSynced(key);
  }

  /// Uploads all locally unsynced trips to `POST /api/trips`.
  /// Returns the number of trips successfully uploaded.
  Future<int> uploadPendingTrips() async {
    if (endpoint.isEmpty) return 0;

    final uri = Uri.parse('$endpoint/api/trips');
    final pending = db.getTripsWithKeys()
      ..removeWhere((t) => t['synced'] == true);
    var uploaded = 0;

    for (final trip in pending) {
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
      } catch (_) {
        // Skip this trip and continue with the rest.
      } finally {
        client.close(force: true);
      }
    }

    return uploaded;
  }

  // ── Download (server → admin device) ─────────────────────────────────────

  /// Fetches all trips from `GET /api/trips` and caches them locally
  /// in the `server_trips` Hive box.
  /// Returns the list of trip maps on success, throws on error.
  Future<List<Map<String, dynamic>>> downloadAllTrips({
    String? userId,
    String? mode,
  }) async {
    if (endpoint.isEmpty) {
      throw Exception(
        'No backend endpoint configured. '
        'Build with --dart-define=NATPAC_SYNC_ENDPOINT=http://<host>:3000',
      );
    }

    var url = '$endpoint/api/trips';
    final params = <String, String>{};
    if (userId != null && userId.isNotEmpty) params['userId'] = userId;
    if (mode != null && mode.isNotEmpty) params['mode'] = mode;
    if (params.isNotEmpty) {
      url += '?' + params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    }

    final uri = Uri.parse(url);
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      request.headers.set('Accept', 'application/json');
      final response = await request.close();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Server returned HTTP ${response.statusCode}');
      }

      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final trips = (decoded['trips'] as List)
          .cast<Map<String, dynamic>>();

      // Cache in the server_trips Hive box.
      db.cacheServerTrips(trips);

      return trips;
    } finally {
      client.close(force: true);
    }
  }

  // ── Stats ─────────────────────────────────────────────────────────────────

  /// Fetches aggregate stats from `GET /api/stats`.
  Future<Map<String, dynamic>> fetchStats() async {
    if (endpoint.isEmpty) throw Exception('No backend endpoint configured.');

    final uri = Uri.parse('$endpoint/api/stats');
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      request.headers.set('Accept', 'application/json');
      final response = await request.close();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Server returned HTTP ${response.statusCode}');
      }

      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      return decoded['stats'] as Map<String, dynamic>;
    } finally {
      client.close(force: true);
    }
  }
}
