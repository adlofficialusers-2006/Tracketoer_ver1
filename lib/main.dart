import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'modules/background/background_trip_service.dart';
import 'modules/location/location_tracking_module.dart';
import 'modules/ml/transport_mode_predictor.dart';
import 'modules/storage/local_db.dart';
import 'modules/traffic/crowd_detection_service.dart';
import 'ui/screens/consent_screen.dart';
import 'ui/screens/home_screen.dart';
import 'modules/trip/trip_lifecycle_controller.dart';
import 'ui/screens/consent_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await LocalDB.openBoxes();
  final transportModePredictor = await TransportModePredictor.loadFromAsset();
  await BackgroundTripService.configure();

  // Check if location consent was already given
  final db = LocalDB();
  final consentGiven = db.getLocationConsentGiven();

  runApp(MyApp(
    transportModePredictor: transportModePredictor,
    showConsentScreen: !consentGiven,
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.transportModePredictor,
    this.showConsentScreen = true,
  });

  final TransportModePredictor transportModePredictor;
  final bool showConsentScreen;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => LocalDB()),
        ChangeNotifierProvider(
          create: (context) {
            final db = context.read<LocalDB>();
            return TripLifecycleController(
              locationModule: LocationTrackingModule(),
              db: db,
              crowdDetectionService: CrowdDetectionService(db: db),
              transportModePredictor: transportModePredictor,
            );
          },
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Travel Tracker',
        theme: AppTheme.dark,
        home: showConsentScreen ? const ConsentScreen() : HomeScreen(),
      ),
    );
  }
}
