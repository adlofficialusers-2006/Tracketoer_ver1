import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../modules/location/location_tracking_module.dart';
import '../../modules/storage/local_db.dart';
import '../../ui/screens/home_screen.dart';

class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  final LocationTrackingModule locationModule = LocationTrackingModule();
  final LocalDB db = LocalDB();
  bool locationConsent = true;
  bool isLoading = false;
  String message =
      'Enable always-on location permission to detect trips automatically.';

  Future<void> requestConsent() async {
    if (!locationConsent) {
      setState(() {
        message = 'Please enable the location toggle before continuing.';
      });
      return;
    }

    setState(() {
      isLoading = true;
      message = 'Requesting location permission from the device...';
    });

    final granted = await locationModule.requestPermission();

    setState(() {
      isLoading = false;
    });

    if (granted) {
      // Save consent status
      db.setLocationConsentGiven(true);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      setState(() {
        message =
            'Permission denied. Please allow always-on location access to track trips.';
        locationConsent = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    const SizedBox(height: 12),
                    Text(
                      'travel Tracker',
                      style: TextStyle(
                        color: AppColors.neonPurple,
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'A premium travel research app that captures automatic trips and guides users to add travel details securely.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 16,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Data Collection Overview',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildBullet(
                            'Background GPS trip detection for start/end capture',
                          ),
                          _buildBullet(
                            'Distance, duration, and route summary storage',
                          ),
                          _buildBullet(
                            'User-provided mode, purpose, cost, and companions',
                          ),
                          _buildBullet(
                            'ML-based mode prediction after each trip',
                          ),
                          _buildBullet(
                            'Local storage with safe sync-ready state',
                          ),
                          const SizedBox(height: 8),
                          SwitchListTile.adaptive(
                            value: locationConsent,
                            onChanged: (value) =>
                                setState(() => locationConsent = value),
                            title: const Text(
                              'Enable Location Permission',
                              style: TextStyle(color: Colors.white),
                            ),
                            subtitle: const Text(
                              'Choose Allow all the time when the device asks.',
                              style: TextStyle(color: Colors.white60),
                            ),
                            activeThumbColor: AppColors.neonBlue,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      message,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : requestConsent,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.neonBlue,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.black,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Agree & Continue',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBullet(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '- ',
            style: TextStyle(color: AppColors.neonBlue, fontSize: 18),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
