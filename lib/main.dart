import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'modules/auth/auth_service.dart';
import 'modules/background/background_trip_service.dart';
import 'modules/location/location_tracking_module.dart';
import 'modules/ml/transport_mode_predictor.dart';
import 'modules/storage/local_db.dart';
import 'modules/traffic/crowd_detection_service.dart';
import 'modules/trip/trip_lifecycle_controller.dart';
import 'ui/screens/admin_dashboard_screen.dart';
import 'ui/screens/consent_screen.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await LocalDB.openBoxes();

  // Load ML model — fall back to a stub predictor if the asset is missing.
  TransportModePredictor predictor;
  try {
    predictor = await TransportModePredictor.loadFromAsset();
  } catch (_) {
    predictor = TransportModePredictor.fallback();
  }

  // Configure background service — non-fatal if platform channel fails.
  try {
    await BackgroundTripService.configure();
  } catch (_) {}

  // Initialize auth (synchronous — reads from already-open Hive boxes).
  final authService = AuthService()..initialize();

  runApp(
    MyApp(
      transportModePredictor: predictor,
      authService: authService,
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.transportModePredictor,
    required this.authService,
  });

  final TransportModePredictor transportModePredictor;
  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authService),
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
        title: 'NATPAC Travel Tracker',
        theme: AppTheme.dark,
        home: const _AuthGate(),
      ),
    );
  }
}

/// Listens to [AuthService] and routes to the appropriate starting screen.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    if (!auth.isLoggedIn) {
      return const LoginScreen();
    }

    if (auth.currentRole == 'admin') {
      return const AdminDashboardScreen();
    }

    // Logged in as user — check location consent.
    if (!auth.hasLocationConsent) {
      return const ConsentScreen();
    }

    return const HomeScreen();
  }
}
