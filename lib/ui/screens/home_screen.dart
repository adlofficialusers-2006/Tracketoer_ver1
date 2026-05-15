import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../modules/auth/auth_service.dart';
import '../../modules/background/background_trip_service.dart';
import '../../modules/storage/local_db.dart';
import '../../modules/sync/auto_sync_service.dart';
import '../../modules/traffic/traffic_event.dart';
import '../../modules/trip/trip_lifecycle_controller.dart';
import '../../modules/trip/trip_model.dart';
import '../../ui/widgets/glass_card.dart';
import '../../ui/widgets/post_trip_sheet.dart';
import '../../ui/widgets/pulse_badge.dart';
import 'settings_screen.dart';
import 'trip_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  static const LatLng _defaultCameraTarget = LatLng(8.5241, 76.9366);

  final List<LatLng> _routePoints = [];
  final MapController _mapController = MapController();
  late final AnimationController _markerController;
  late Animation<double> _markerAnimation;
  late final AutoSyncService _autoSync;
  TripLifecycleController? _tracker;
  LatLng? _markerAnimationStart;
  LatLng? _markerAnimationEnd;
  LatLng? _lastSyncedTarget;
  LatLng? _animatedPosition;
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _markerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..addListener(_updateAnimatedMarker);
    _markerAnimation = CurvedAnimation(
      parent: _markerController,
      curve: Curves.easeOutCubic,
    );
    _autoSync = AutoSyncService(db: context.read<LocalDB>())..start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _mapReady = true);
      final tracker = context.read<TripLifecycleController>();
      _tracker = tracker;
      BackgroundTripService.stop();
      tracker.start();
      tracker.addListener(_onTrackerChanged);
    });
  }

  void _onTrackerChanged() {
    final tracker = _tracker;
    if (tracker == null) return;
    final key = tracker.pendingReviewKey;
    if (key == null) return;
    tracker.clearPendingReview();
    // Small delay so the trip-end UI settles before the sheet appears.
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      showPostTripSheet(
        context,
        tripKey: key,
        db: context.read<LocalDB>(),
      );
    });
  }

  @override
  void dispose() {
    _autoSync.stop();
    _tracker?.removeListener(_onTrackerChanged);
    WidgetsBinding.instance.removeObserver(this);
    _markerController
      ..removeListener(_updateAnimatedMarker)
      ..dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final tracker = _tracker;
    if (tracker == null) return;
    if (state == AppLifecycleState.resumed) {
      // Wait for background service to stop before starting the foreground tracker
      // so both don't hold the location stream simultaneously.
      BackgroundTripService.stop().then((_) {
        if (mounted) tracker.start();
      });
      return;
    }

    // Only hand off to the background service when the app is fully backgrounded.
    // Ignore `inactive` (e.g. notification shade pulled down) to avoid
    // constantly stopping/restarting tracking on trivial interruptions.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      tracker.stop();
      BackgroundTripService.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tracker = context.watch<TripLifecycleController>();
    final position = tracker.currentPosition;
    final currentTarget = position == null
        ? null
        : LatLng(position.latitude, position.longitude);
    _syncMovingPosition(currentTarget);
    _syncPolyline(tracker, currentTarget);

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: _buildDrawer(context),
      floatingActionButton: FloatingActionButton(
        backgroundColor: tracker.hasActiveTrip
            ? AppColors.neonPurple
            : AppColors.neonBlue,
        foregroundColor: Colors.black,
        tooltip: tracker.hasActiveTrip ? 'End trip' : 'Start trip',
        onPressed: tracker.hasActiveTrip
            ? tracker.manualEnd
            : tracker.manualStart,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Icon(
            tracker.hasActiveTrip
                ? Icons.stop_rounded
                : Icons.play_arrow_rounded,
            key: ValueKey(tracker.hasActiveTrip),
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.58,
              width: double.infinity,
              child: _buildLiveMapDashboard(tracker, currentTarget),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 92),
                child: Column(
                  children: [
                    if (tracker.needsStopConfirmation) ...[
                      _buildStopConfirmation(tracker),
                      const SizedBox(height: 16),
                    ],
                    _buildTripDetectionCard(tracker),
                    const SizedBox(height: 16),
                    _buildMetricsCard(tracker),
                    const SizedBox(height: 16),
                    _buildCrowdCard(tracker),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveMapDashboard(
    TripLifecycleController tracker,
    LatLng? currentTarget,
  ) {
    final active = tracker.status != TripStatus.idle;
    final cameraTarget = currentTarget ?? _defaultCameraTarget;

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(34),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.neonPurple.withValues(alpha: 0.25),
                  blurRadius: 30,
                  spreadRadius: 1,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(34),
              ),
              child: AnimatedOpacity(
                opacity: _mapReady ? 1 : 0,
                duration: const Duration(milliseconds: 650),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: cameraTarget,
                    initialZoom: currentTarget == null ? 13 : 16.8,
                    interactionOptions: const InteractionOptions(
                      flags:
                          InteractiveFlag.drag |
                          InteractiveFlag.pinchZoom |
                          InteractiveFlag.doubleTapZoom,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'govt_tracker_version_1',
                      retinaMode: RetinaMode.isHighDensity(context),
                    ),
                    if (_routePoints.length >= 2)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _routePoints,
                            color: AppColors.neonPurple.withValues(alpha: 0.36),
                            strokeWidth: 14,
                          ),
                          Polyline(
                            points: _routePoints,
                            color: AppColors.neonAccent,
                            strokeWidth: 6,
                          ),
                        ],
                      ),
                    MarkerLayer(markers: _buildMarkers(tracker, currentTarget)),
                    RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution(
                          'OpenStreetMap contributors',
                          textStyle: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (!_mapReady) _buildMapLoading(),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(34),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.38),
                    Colors.transparent,
                    AppColors.background.withValues(alpha: 0.78),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          top: 16,
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.38),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.neonPurple.withValues(alpha: 0.5),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(
                    'assets/images/logo.jpeg',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MapGlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        active ? 'Tracking Active' : 'Ready to Track',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _LiveIndicator(active: active),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tracker.status.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 22,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _MapMetricCard(
                      label: 'Distance',
                      value: formatDistance(tracker.distanceMeters),
                      icon: Icons.route_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MapMetricCard(
                      label: 'Duration',
                      value: formatDuration(tracker.elapsedDuration),
                      icon: Icons.timer_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MapGlassPanel(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.navigation_rounded,
                            color: AppColors.neonBlue,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              currentTarget == null
                                  ? 'Waiting for GPS lock'
                                  : '${tracker.currentSpeedKmph.toStringAsFixed(1)} km/h live speed',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _openTrips,
                      icon: const Icon(Icons.history_rounded, size: 18),
                      label: const Text('View Trips'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.neonPurple,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Marker> _buildMarkers(
    TripLifecycleController tracker,
    LatLng? currentTarget,
  ) {
    final markers = <Marker>[];
    final start = tracker.tripStartPosition;
    if (start != null) {
      markers.add(
        Marker(
          point: LatLng(start.latitude, start.longitude),
          width: 42,
          height: 42,
          child: Icon(
            Icons.location_on_rounded,
            color: AppColors.neonBlue,
            size: 42,
          ),
        ),
      );
    }

    final movingPosition = _animatedPosition ?? currentTarget;
    if (movingPosition != null) {
      markers.add(
        Marker(
          point: movingPosition,
          width: 44,
          height: 44,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.neonPurple.withValues(alpha: 0.18),
              border: Border.all(color: AppColors.neonPurple, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.neonPurple.withValues(alpha: 0.38),
                  blurRadius: 18,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Icon(
              Icons.navigation_rounded,
              color: AppColors.neonAccent,
              size: 22,
            ),
          ),
        ),
      );
    }

    return markers;
  }

  void _syncMovingPosition(LatLng? nextPosition) {
    if (nextPosition == null) return;
    if (_lastSyncedTarget != null &&
        _sameLatLng(_lastSyncedTarget!, nextPosition)) {
      return;
    }

    final previous = _animatedPosition ?? nextPosition;
    _lastSyncedTarget = nextPosition;
    if (_sameLatLng(previous, nextPosition)) {
      _animatedPosition = nextPosition;
      _animateCameraTo(nextPosition);
      return;
    }

    _markerAnimationStart = previous;
    _markerAnimationEnd = nextPosition;
    _markerController.forward(from: 0);
    _animateCameraTo(nextPosition);
  }

  void _syncPolyline(TripLifecycleController tracker, LatLng? currentTarget) {
    final points = tracker.routePositions
        .map((position) => LatLng(position.latitude, position.longitude))
        .toList();
    final movingPoint = _animatedPosition ?? currentTarget;
    if (movingPoint != null &&
        (points.isEmpty || !_sameLatLng(points.last, movingPoint))) {
      points.add(movingPoint);
    }

    _routePoints
      ..clear()
      ..addAll(points);
  }

  void _updateAnimatedMarker() {
    final start = _markerAnimationStart;
    final end = _markerAnimationEnd;
    if (start == null || end == null) return;
    final value = _markerAnimation.value;
    setState(() {
      _animatedPosition = LatLng(
        start.latitude + ((end.latitude - start.latitude) * value),
        start.longitude + ((end.longitude - start.longitude) * value),
      );
    });
  }

  void _animateCameraTo(LatLng target) {
    if (!_mapReady) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _mapController.move(target, 16.8);
      } catch (_) {
        // The map controller is attached after the first FlutterMap layout pass.
      }
    });
  }

  bool _sameLatLng(LatLng first, LatLng second) {
    return (first.latitude - second.latitude).abs() < 0.000001 &&
        (first.longitude - second.longitude).abs() < 0.000001;
  }

  Widget _buildMapLoading() {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(34)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF070B17), Color(0xFF11152A), Color(0xFF050915)],
          ),
        ),
        child: Center(
          child: Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.neonPurple.withValues(alpha: 0.45),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.neonPurple.withValues(alpha: 0.32),
                  blurRadius: 26,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/logo.jpeg',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTripDetectionCard(TripLifecycleController tracker) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Trip Detection',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _feedbackLabel(tracker),
            style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              PulseBadge(label: 'Started', active: tracker.hasActiveTrip),
              PulseBadge(
                label: 'Traffic',
                active: tracker.status == TripStatus.trafficDelay,
              ),
              PulseBadge(
                label: 'Stop Check',
                active: tracker.needsStopConfirmation,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsCard(TripLifecycleController tracker) {
    final position = tracker.currentPosition;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Live Metrics',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildMetricBlock(
                'Speed',
                '${tracker.currentSpeedKmph.toStringAsFixed(1)} km/h',
              ),
              const SizedBox(width: 18),
              _buildMetricBlock(
                'Elapsed',
                formatDuration(tracker.elapsedDuration),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _buildMetricBlock(
                'Avg speed',
                '${tracker.currentFeatures.avgSpeedKmph.toStringAsFixed(1)} km/h',
              ),
              const SizedBox(width: 18),
              _buildMetricBlock(
                'Idle',
                '${(tracker.currentFeatures.idleRatio * 100).toStringAsFixed(0)}%',
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _buildMetricBlock(
                'Latitude',
                formatCoordinate(position?.latitude),
              ),
              const SizedBox(width: 18),
              _buildMetricBlock(
                'Longitude',
                formatCoordinate(position?.longitude),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCrowdCard(TripLifecycleController tracker) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Crowd Intelligence',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            tracker.crowdResult.isTraffic
                ? '${tracker.crowdResult.level.label} detected from ${tracker.crowdResult.stationaryUsers} nearby stationary users.'
                : 'No nearby stationary crowd cluster detected.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 15,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: _buildStatusChip(
                  tracker.status.label,
                  tracker.status != TripStatus.idle,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: _buildStatusChip(
                  tracker.crowdResult.isTraffic ? 'Congested' : 'Clear',
                  tracker.crowdResult.isTraffic,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStopConfirmation(TripLifecycleController tracker) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Did your trip end?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'You have been stationary for a while. Confirm this as a true stop or resume if you are still travelling.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.45),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: tracker.confirmTripEnded,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.neonPurple,
                  ),
                  child: const Text('Yes, end'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: tracker.resumeTrip,
                  child: const Text('No, resume'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _feedbackLabel(TripLifecycleController tracker) {
    switch (tracker.status) {
      case TripStatus.idle:
        return 'Waiting for consistent movement to begin a trip.';
      case TripStatus.moving:
        return 'Movement detected. Confirming this is not GPS noise.';
      case TripStatus.active:
        return 'Trip is active. True stop time will be excluded automatically.';
      case TripStatus.paused:
      case TripStatus.potentialStop:
        return 'Potential stop detected. User confirmation is required.';
      case TripStatus.trafficDelay:
        return 'Traffic delay detected. Timer continues because congestion counts as travel time.';
    }
  }

  Widget _buildStatusChip(String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: active
            ? AppColors.neonBlue.withValues(alpha: 0.16)
            : AppColors.panel,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: active ? AppColors.neonBlue : AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildMetricBlock(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _openTrips() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TripListScreen()),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.currentUser;
    final initials = user == null || user.name.trim().isEmpty
        ? '?'
        : user.name.trim().split(' ').take(2).map((w) => w[0].toUpperCase()).join();

    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          children: [
            // Profile header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.panel,
                border: Border(
                  bottom: BorderSide(color: AppColors.border),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.neonPurple.withValues(alpha: 0.22),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.neonPurple.withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: TextStyle(
                          color: AppColors.neonPurple,
                          fontWeight: FontWeight.w900,
                          fontSize: 26,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    user?.name ?? 'User',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? '',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.neonBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.neonBlue.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      'NATPAC Contributor',
                      style: TextStyle(
                        color: AppColors.neonBlue,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Menu items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _DrawerItem(
                    icon: Icons.home_rounded,
                    label: 'Dashboard',
                    active: true,
                    onTap: () => Navigator.pop(context),
                  ),
                  _DrawerItem(
                    icon: Icons.history_rounded,
                    label: 'My Trips',
                    onTap: () {
                      Navigator.pop(context);
                      _openTrips();
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.settings_rounded,
                    label: 'Settings',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Logout at bottom
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _handleLogout(auth),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Sign out'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogout(AuthService auth) async {
    await auth.logout();
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: active
              ? AppColors.neonPurple.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: active ? AppColors.neonPurple : AppColors.textSecondary,
          size: 20,
        ),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: active ? Colors.white : AppColors.textSecondary,
          fontWeight: active ? FontWeight.w700 : FontWeight.normal,
        ),
      ),
      onTap: onTap,
    );
  }
}

class _MapGlassPanel extends StatelessWidget {
  const _MapGlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFF070B17).withValues(alpha: 0.64),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.neonPurple.withValues(alpha: 0.26)),
        boxShadow: [
          BoxShadow(
            color: AppColors.neonPurple.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _MapMetricCard extends StatelessWidget {
  const _MapMetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return _MapGlassPanel(
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.neonBlue.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.neonBlue, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveIndicator extends StatefulWidget {
  const _LiveIndicator({required this.active});

  final bool active;

  @override
  State<_LiveIndicator> createState() => _LiveIndicatorState();
}

class _LiveIndicatorState extends State<_LiveIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.active) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _LiveIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.active && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final pulse = widget.active ? _controller.value : 0.0;
        return Container(
          width: 11 + (pulse * 7),
          height: 11 + (pulse * 7),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.active
                ? AppColors.neonAccent
                : AppColors.textSecondary,
            boxShadow: widget.active
                ? [
                    BoxShadow(
                      color: AppColors.neonAccent.withValues(
                        alpha: 0.24 + (pulse * 0.32),
                      ),
                      blurRadius: 12 + (pulse * 10),
                      spreadRadius: 1 + (pulse * 3),
                    ),
                  ]
                : null,
          ),
        );
      },
    );
  }
}
