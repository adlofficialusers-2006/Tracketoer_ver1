import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../modules/storage/local_db.dart';
import '../../modules/trip/trip_model.dart';
import '../../ui/widgets/glass_card.dart';
import 'trip_detail_screen.dart';
import 'trip_form_screen.dart';

class TripListScreen extends StatefulWidget {
  const TripListScreen({super.key});

  @override
  State<TripListScreen> createState() => _TripListScreenState();
}

class _TripListScreenState extends State<TripListScreen> {
  final LocalDB db = LocalDB();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Trip History'), elevation: 0),
      body: ValueListenableBuilder(
        valueListenable: db.box.listenable(),
        builder: (context, box, _) {
          final trips = db.getTripsWithKeys();

          if (trips.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.directions_car_filled,
                    size: 72,
                    color: Colors.white24,
                  ),
                  SizedBox(height: 18),
                  Text(
                    'No trips recorded yet.',
                    style: TextStyle(color: Colors.white70, fontSize: 18),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Start moving to detect and save your first trip.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 15),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemCount: trips.length,
            itemBuilder: (context, index) {
              final tripMap = trips[index];
              final key = tripMap['key'];
              final trip = Trip.fromMap(tripMap);

              return GlassCard(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 16,
                  ),
                  title: Text(
                    'Trip ${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        'Distance: ${formatDistance(trip.distance)}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Duration: ${formatDuration(trip.duration)}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Mode: ${trip.mode}'
                        '${trip.modeSource == 'ml' ? ' (${(trip.modeConfidence * 100).toStringAsFixed(0)}%)' : ''}',
                        style: const TextStyle(color: AppColors.neonBlue),
                      ),
                      if (trip.trafficDelayDuration > Duration.zero) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Traffic delay: ${formatDuration(trip.trafficDelayDuration)}',
                          style: const TextStyle(color: AppColors.neonPurple),
                        ),
                      ],
                    ],
                  ),
                  trailing: Wrap(
                    spacing: 6,
                    children: [
                      IconButton(
                        tooltip: 'Edit trip',
                        icon: const Icon(
                          Icons.edit_rounded,
                          color: AppColors.neonPurple,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  TripFormScreen(trip: trip, tripKey: key),
                            ),
                          );
                        },
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        color: AppColors.neonBlue,
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TripDetailScreen(trip: tripMap),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
