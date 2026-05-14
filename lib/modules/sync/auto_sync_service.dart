import 'dart:async';

import '../storage/local_db.dart';
import 'trip_sync_service.dart';

/// Uploads pending trips to the backend once every 24 hours.
///
/// On [start]:
///   - If 24 h have already passed since the last upload, syncs immediately.
///   - Otherwise waits for the remaining time, then repeats every 24 h.
///
/// Call [start] from HomeScreen.initState and [stop] from HomeScreen.dispose.
class AutoSyncService {
  AutoSyncService({required this.db});

  final LocalDB db;
  Timer? _timer;

  static const _lastSyncKey = 'last_auto_sync_at';
  static const _interval = Duration(hours: 24);

  void start() {
    stop(); // cancel any existing timer before starting a new one
    final lastSyncStr = db.getSetting<String>(_lastSyncKey);
    final lastSync =
        lastSyncStr != null ? DateTime.tryParse(lastSyncStr) : null;
    final now = DateTime.now();

    if (lastSync == null || now.difference(lastSync) >= _interval) {
      // Overdue — sync straight away, then repeat every 24 h.
      _doSync();
      _timer = Timer.periodic(_interval, (_) => _doSync());
    } else {
      // Not yet due — wait for the remaining window, then go periodic.
      final remaining = _interval - now.difference(lastSync);
      _timer = Timer(remaining, () {
        _doSync();
        _timer = Timer.periodic(_interval, (_) => _doSync());
      });
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _doSync() async {
    try {
      final uploaded = await TripSyncService(db: db).uploadPendingTrips();
      if (uploaded > 0) {
        db.setSetting(_lastSyncKey, DateTime.now().toIso8601String());
      }
    } catch (_) {
      // Silent — will retry on the next 24 h tick.
    }
  }
}
