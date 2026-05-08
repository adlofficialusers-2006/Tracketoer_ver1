import 'dart:async';
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../location/location_tracking_module.dart';
import '../ml/transport_mode_predictor.dart';
import '../storage/local_db.dart';
import '../traffic/crowd_detection_service.dart';
import '../trip/trip_lifecycle_controller.dart';
import '../trip/trip_model.dart';

class BackgroundTripService {
  static const _notificationId = 25082;
  static const _channelId = 'natpac_trip_capture';

  static Future<void> configure() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: _channelId,
        initialNotificationTitle: 'Travel tracking active',
        initialNotificationContent: 'Capturing trip movement in background',
        foregroundServiceNotificationId: _notificationId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onStart,
        onBackground: _onIosBackground,
      ),
    );
  }

  static Future<void> start() async {
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    if (!isRunning) {
      await service.startService();
    }
  }

  static Future<void> stop() async {
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    if (isRunning) {
      service.invoke('stopService');
    }
  }
}

@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
Future<void> _onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  await Hive.initFlutter();
  await LocalDB.openBoxes();

  if (service is AndroidServiceInstance) {
    await service.setAsForegroundService();
    service.setForegroundNotificationInfo(
      title: 'Travel tracking active',
      content: 'Automatic trip detection is running',
    );
  }

  final db = LocalDB();
  final predictor = await TransportModePredictor.loadFromAsset();
  final controller = TripLifecycleController(
    locationModule: LocationTrackingModule(),
    db: db,
    crowdDetectionService: CrowdDetectionService(db: db),
    transportModePredictor: predictor,
    deviceId: 'background-device',
  );

  await controller.start();

  Timer? heartbeat;
  heartbeat = Timer.periodic(const Duration(seconds: 30), (_) {
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: 'Travel tracking active',
        content:
            '${controller.status.label} - ${controller.currentSpeedKmph.toStringAsFixed(1)} km/h',
      );
    }
  });

  service.on('stopService').listen((_) async {
    heartbeat?.cancel();
    await controller.stop();
    controller.dispose();
    service.stopSelf();
  });
}
