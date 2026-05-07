import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../ui/widgets/glass_card.dart';

class TripDetailScreen extends StatelessWidget {
  final Map<String, dynamic> trip;

  const TripDetailScreen({super.key, required this.trip});

  Widget _buildSection(String title, List<Widget> children) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(value, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final duration = trip['duration'] is int
        ? Duration(seconds: trip['duration'] as int)
        : const Duration();
    final pausedDuration = trip['pausedDuration'] is int
        ? Duration(seconds: trip['pausedDuration'] as int)
        : const Duration();
    final trafficDelayDuration = trip['trafficDelayDuration'] is int
        ? Duration(seconds: trip['trafficDelayDuration'] as int)
        : const Duration();
    final distance = trip['distance'] is num
        ? (trip['distance'] as num).toDouble()
        : 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Trip Details'), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection('Route Overview', [
              _buildRow('Start', trip['start'] ?? 'Unknown'),
              _buildRow('End', trip['end'] ?? 'Unknown'),
              _buildRow('Distance', formatDistance(distance)),
              _buildRow('Duration', formatDuration(duration)),
              _buildRow('Paused time', formatDuration(pausedDuration)),
              _buildRow('Traffic delay', formatDuration(trafficDelayDuration)),
            ]),
            const SizedBox(height: 16),
            _buildSection('Travel Details', [
              _buildRow('Mode', trip['mode'] ?? 'Unknown'),
              _buildRow(
                'Mode confidence',
                '${(((trip['modeConfidence'] as num?)?.toDouble() ?? 0) * 100).toStringAsFixed(0)}%',
              ),
              _buildRow('Mode source', trip['modeSource'] ?? 'Unknown'),
              _buildRow('Purpose', trip['purpose'] ?? 'Unknown'),
              _buildRow('Cost', trip['cost'] ?? 'Unknown'),
              _buildRow('Companions', trip['companions'] ?? 'Unknown'),
              _buildRow('Frequency', trip['frequency'] ?? 'Unknown'),
            ]),
            const SizedBox(height: 16),
            _buildSection('Movement Metrics', [
              _buildRow(
                'Average speed',
                '${((trip['avgSpeedKmph'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)} km/h',
              ),
              _buildRow(
                'Idle ratio',
                '${(((trip['idleRatio'] as num?)?.toDouble() ?? 0) * 100).toStringAsFixed(0)}%',
              ),
              _buildRow(
                'Acceleration variance',
                ((trip['accelerationVariance'] as num?)?.toDouble() ?? 0)
                    .toStringAsFixed(2),
              ),
              _buildRow(
                'Average stop',
                '${((trip['avgStopDurationSec'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)} sec',
              ),
              _buildRow(
                'Stops per hour',
                ((trip['stopFrequencyPerHr'] as num?)?.toDouble() ?? 0)
                    .toStringAsFixed(1),
              ),
            ]),
            const SizedBox(height: 16),
            _buildSection('Timeline', [
              _buildRow(
                'Started',
                formatDateTime(trip['startTime'] ?? 'Unknown'),
              ),
              _buildRow('Ended', formatDateTime(trip['endTime'] ?? 'Unknown')),
            ]),
          ],
        ),
      ),
    );
  }
}
