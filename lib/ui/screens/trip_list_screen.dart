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

  String? _filterMode;
  String? _filterPurpose;

  static const _modes = [
    'Car', 'Motorcycle', 'Bus', 'Heavy vehicle', 'Train', 'Walk', 'Unknown'
  ];
  static const _purposes = [
    'Work', 'Home', 'Shopping', 'Leisure', 'Education', 'Unknown'
  ];

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> trips) {
    return trips.where((t) {
      if (_filterMode != null &&
          (t['mode'] as String? ?? 'Unknown') != _filterMode) return false;
      if (_filterPurpose != null &&
          (t['purpose'] as String? ?? 'Unknown') != _filterPurpose) return false;
      return true;
    }).toList();
  }

  void _showFilterSheet(List<Map<String, dynamic>> allTrips) {
    final availableModes = allTrips
        .map((t) => t['mode'] as String? ?? 'Unknown')
        .toSet()
        .toList()
      ..sort();
    final availablePurposes = allTrips
        .map((t) => t['purpose'] as String? ?? 'Unknown')
        .toSet()
        .toList()
      ..sort();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setSheet) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filter Trips',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _filterMode = null;
                            _filterPurpose = null;
                          });
                          Navigator.pop(context);
                        },
                        child: Text(
                          'Clear all',
                          style: TextStyle(color: AppColors.neonPurple),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Mode',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _FilterOption(
                        label: 'All',
                        selected: _filterMode == null,
                        onTap: () => setSheet(() => _filterMode = null),
                      ),
                      ...availableModes
                          .where((m) => _modes.contains(m))
                          .map((m) => _FilterOption(
                                label: m,
                                selected: _filterMode == m,
                                onTap: () => setSheet(() => _filterMode = m),
                              )),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Purpose',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _FilterOption(
                        label: 'All',
                        selected: _filterPurpose == null,
                        onTap: () => setSheet(() => _filterPurpose = null),
                      ),
                      ...availablePurposes
                          .where((p) => _purposes.contains(p))
                          .map((p) => _FilterOption(
                                label: p,
                                selected: _filterPurpose == p,
                                onTap: () =>
                                    setSheet(() => _filterPurpose = p),
                              )),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.neonPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        setState(() {});
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Apply',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  bool get _hasActiveFilter => _filterMode != null || _filterPurpose != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Trip History'),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Filter',
            icon: Stack(
              children: [
                const Icon(Icons.filter_list_rounded),
                if (_hasActiveFilter)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.neonPurple,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () {
              final userId = db.currentUserId;
              final all = db.getTripsWithKeys(
                  userId: userId.isEmpty ? null : userId);
              _showFilterSheet(all);
            },
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: db.box.listenable(),
        builder: (context, box, _) {
          final userId = db.currentUserId;
          final all = db.getTripsWithKeys(
              userId: userId.isEmpty ? null : userId);
          final trips = _applyFilters(all);

          if (all.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions_car_filled,
                      size: 72, color: Colors.white24),
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

          return Column(
            children: [
              if (_hasActiveFilter)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: AppColors.neonPurple, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'Showing ${trips.length} of ${all.length} trips',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: trips.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off_rounded,
                                size: 64, color: Colors.white24),
                            const SizedBox(height: 16),
                            Text(
                              'No trips match the filter.',
                              style: TextStyle(
                                  color: AppColors.textSecondary, fontSize: 15),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(20),
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 16),
                        itemCount: trips.length,
                        itemBuilder: (context, index) {
                          final tripMap = trips[index];
                          final key = tripMap['key'];
                          final trip = Trip.fromMap(tripMap);
                          final incomplete = trip.purpose == 'Unknown' &&
                              trip.cost == '0';

                          return GlassCard(
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 16, horizontal: 16),
                              title: Row(
                                children: [
                                  Text(
                                    'Trip ${tripMap['tripNumber'] ?? index + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (incomplete) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.orangeAccent
                                            .withValues(alpha: 0.15),
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'Incomplete',
                                        style: TextStyle(
                                          color: Colors.orangeAccent,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 8),
                                  Text(
                                    '${formatDistance(trip.distance)}  ·  ${formatDuration(trip.duration)}',
                                    style: const TextStyle(
                                        color: Colors.white70),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Mode: ${trip.mode}'
                                    '${trip.modeSource == 'ml' ? ' (${(trip.modeConfidence * 100).toStringAsFixed(0)}%)' : ''}',
                                    style: TextStyle(
                                        color: AppColors.neonBlue),
                                  ),
                                  if (trip.purpose != 'Unknown') ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Purpose: ${trip.purpose}',
                                      style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12),
                                    ),
                                  ],
                                  if (trip.trafficDelayDuration >
                                      Duration.zero) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Traffic delay: ${formatDuration(trip.trafficDelayDuration)}',
                                      style: TextStyle(
                                          color: AppColors.neonPurple),
                                    ),
                                  ],
                                ],
                              ),
                              trailing: Wrap(
                                spacing: 6,
                                children: [
                                  IconButton(
                                    tooltip: 'Edit trip',
                                    icon: Icon(
                                      Icons.edit_rounded,
                                      color: incomplete
                                          ? Colors.orangeAccent
                                          : AppColors.neonPurple,
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => TripFormScreen(
                                              trip: trip, tripKey: key),
                                        ),
                                      );
                                    },
                                  ),
                                  Icon(Icons.arrow_forward_ios,
                                      color: AppColors.neonBlue, size: 16),
                                ],
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        TripDetailScreen(trip: tripMap),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FilterOption extends StatelessWidget {
  const _FilterOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.neonPurple.withValues(alpha: 0.2)
              : AppColors.panel,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.neonPurple.withValues(alpha: 0.7)
                : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.neonPurple : AppColors.textSecondary,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
