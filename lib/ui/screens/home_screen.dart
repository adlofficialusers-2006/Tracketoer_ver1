import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../modules/background/background_trip_service.dart';
import '../../modules/traffic/traffic_event.dart';
import '../../modules/trip/trip_lifecycle_controller.dart';
import '../../modules/trip/trip_model.dart';
import '../../ui/widgets/glass_card.dart';
import '../../ui/widgets/pulse_badge.dart';
import 'trip_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      BackgroundTripService.stop();
      context.read<TripLifecycleController>().start();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final tracker = context.read<TripLifecycleController>();
    if (state == AppLifecycleState.resumed) {
      BackgroundTripService.stop();
      tracker.start();
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.inactive) {
      tracker.stop();
      BackgroundTripService.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tracker = context.watch<TripLifecycleController>();
    final size = MediaQuery.of(context).size;
    final heroHeight = size.height * 0.45;
    final position = tracker.currentPosition;

    return Scaffold(
      backgroundColor: AppColors.background,
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
        child: Column(
          children: [
            SizedBox(
              height: heroHeight,
              width: double.infinity,
              child: Stack(
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 1.0, end: 1.04),
                    duration: const Duration(seconds: 16),
                    builder: (context, scale, child) {
                      return Transform.scale(scale: scale, child: child);
                    },
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(32),
                        bottomRight: Radius.circular(32),
                      ),
                      child: Image.asset(
                        'assets/images/home_banner.png',
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.background.withValues(alpha: 0.05),
                            AppColors.background.withValues(alpha: 0.93),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: 28,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'travel Tracker',
                          style: TextStyle(
                            color: AppColors.neonPurple,
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildPulsingDot(tracker.status != TripStatus.idle),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                tracker.status.label,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Distance: ${formatDistance(tracker.distanceMeters)}',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
                child: Column(
                  children: [
                    if (tracker.needsStopConfirmation) ...[
                      _buildStopConfirmation(tracker),
                      const SizedBox(height: 16),
                    ],
                    GlassCard(
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
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              PulseBadge(
                                label: 'Started',
                                active: tracker.hasActiveTrip,
                              ),
                              PulseBadge(
                                label: 'Traffic',
                                active:
                                    tracker.status == TripStatus.trafficDelay,
                              ),
                              PulseBadge(
                                label: 'Stop Check',
                                active: tracker.needsStopConfirmation,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    GlassCard(
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
                    ),
                    const SizedBox(height: 16),
                    GlassCard(
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
                              _buildStatusChip(
                                tracker.status.label,
                                tracker.status != TripStatus.idle,
                              ),
                              _buildStatusChip(
                                tracker.crowdResult.isTraffic
                                    ? 'Congested'
                                    : 'Clear',
                                tracker.crowdResult.isTraffic,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TripListScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.neonPurple,
                          foregroundColor: Colors.black,
                        ),
                        child: const Text(
                          'View Trips',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 72),
                  ],
                ),
              ),
            ),
          ],
        ),
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

  Widget _buildPulsingDot(bool active) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 450),
      width: active ? 16 : 12,
      height: active ? 16 : 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? AppColors.neonBlue : AppColors.textSecondary,
        boxShadow: active
            ? [
                BoxShadow(
                  color: AppColors.neonBlue.withValues(alpha: 0.35),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
    );
  }
}
