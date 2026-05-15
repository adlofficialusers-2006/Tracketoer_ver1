import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../modules/auth/auth_service.dart';
import '../../modules/storage/local_db.dart';
import '../../modules/sync/trip_sync_service.dart';
import '../../modules/trip/trip_model.dart';
import '../../ui/widgets/glass_card.dart';
import 'trip_form_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  final LocalDB _db = LocalDB();
  late final TabController _tabController;
  String? _selectedUserId;
  String? _selectedMode;
  bool _syncing = false;
  bool _fetching = false;
  String? _statusMsg;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.neonBlue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.admin_panel_settings_rounded,
                color: AppColors.neonBlue,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'NATPAC Admin',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        actions: [
          // Upload local → server
          IconButton(
            tooltip: 'Upload unsynced trips to server',
            icon: _syncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.cloud_upload_outlined, color: AppColors.neonAccent),
            onPressed: _syncing ? null : _triggerUpload,
          ),
          // Download server → local (admin only)
          IconButton(
            tooltip: 'Fetch all trips from server',
            icon: _fetching
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.cloud_download_outlined, color: AppColors.neonPurple),
            onPressed: _fetching ? null : _triggerFetch,
          ),
          IconButton(
            tooltip: 'Export trips as CSV',
            icon: Icon(Icons.download_rounded, color: AppColors.neonAccent),
            onPressed: _exportCsv,
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout_rounded, color: Colors.white54),
            onPressed: () => _logout(auth),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          dividerColor: AppColors.border,
          indicatorColor: AppColors.neonPurple,
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
          tabs: [
            const Tab(text: 'Local Data'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Server Data'),
                  if (_db.hasServerTrips) ...[
                    const SizedBox(width: 6),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.neonAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLocalDataTab(auth),
          _buildServerDataTab(auth),
        ],
      ),
    );
  }

  // ── Local data tab ─────────────────────────────────────────────────────────

  Widget _buildLocalDataTab(AuthService auth) {
    return ValueListenableBuilder(
      valueListenable: _db.box.listenable(),
      builder: (context, _, _) {
        final allTrips = _db.getTripsWithKeys();
        final List<AppUser> users = auth.getAllUsers();
        final filtered = _applyFilter(allTrips);

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _buildStatsRow(allTrips, users.length),
            ),
            SliverToBoxAdapter(child: _buildStatusBanner()),
            SliverToBoxAdapter(child: _buildFilterRow(users, allTrips)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  '${filtered.length} trip${filtered.length == 1 ? '' : 's'} shown',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            filtered.isEmpty
                ? SliverFillRemaining(child: _buildEmpty())
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final trip = filtered[index];
                        return Padding(
                          padding: EdgeInsets.fromLTRB(
                            20,
                            index == 0 ? 0 : 8,
                            20,
                            index == filtered.length - 1 ? 32 : 0,
                          ),
                          child: _AdminTripCard(
                            trip: trip,
                            auth: auth,
                            tripKey: trip['key'],
                          ),
                        );
                      },
                      childCount: filtered.length,
                    ),
                  ),
            ],
        );
      },
    );
  }

  // ── Stats row ──────────────────────────────────────────────────────────────

  Widget _buildStatsRow(
    List<Map<String, dynamic>> allTrips,
    int userCount,
  ) {
    final totalDist = allTrips.fold<double>(
      0,
      (sum, t) => sum + ((t['distance'] as num?)?.toDouble() ?? 0),
    );
    final unsynced = allTrips.where((t) => t['synced'] != true).length;
    final modeCounts = <String, int>{};
    for (final t in allTrips) {
      final m = t['mode'] as String? ?? 'Unknown';
      modeCounts[m] = (modeCounts[m] ?? 0) + 1;
    }
    final topMode = modeCounts.entries.isEmpty
        ? 'N/A'
        : (modeCounts.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .first
            .key;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Total Trips',
                  value: '${allTrips.length}',
                  icon: Icons.route_rounded,
                  color: AppColors.neonPurple,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  label: 'Users',
                  value: '$userCount',
                  icon: Icons.people_rounded,
                  color: AppColors.neonBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Total Distance',
                  value: formatDistance(totalDist),
                  icon: Icons.straighten_rounded,
                  color: AppColors.neonAccent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  label: 'Unsynced',
                  value: '$unsynced',
                  icon: Icons.cloud_off_outlined,
                  color: unsynced > 0 ? Colors.orangeAccent : Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildModeBreakdown(modeCounts, allTrips.length, topMode),
        ],
      ),
    );
  }

  Widget _buildModeBreakdown(
    Map<String, int> modeCounts,
    int total,
    String topMode,
  ) {
    if (total == 0) return const SizedBox.shrink();
    const modes = ['Car', 'Bus', 'Motorcycle', 'Heavy vehicle', 'Unknown'];
    final modeColors = {
      'Car': AppColors.neonBlue,
      'Bus': AppColors.neonPurple,
      'Motorcycle': AppColors.neonAccent,
      'Heavy vehicle': Colors.orangeAccent,
      'Unknown': Colors.white24,
    };

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Mode Breakdown',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.neonPurple.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Top: $topMode',
                  style: TextStyle(
                    color: AppColors.neonPurple,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...modes.map((mode) {
            final count = modeCounts[mode] ?? 0;
            if (count == 0) return const SizedBox.shrink();
            final ratio = total > 0 ? count / total : 0.0;
            final color = modeColors[mode] ?? Colors.white24;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        mode,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '$count (${(ratio * 100).toStringAsFixed(0)}%)',
                        style: TextStyle(
                          color: color,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: ratio,
                      backgroundColor: AppColors.panel,
                      valueColor: AlwaysStoppedAnimation(color),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Status banner ──────────────────────────────────────────────────────────

  Widget _buildStatusBanner() {
    if (_statusMsg == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.neonAccent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: AppColors.neonAccent.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.neonAccent, size: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _statusMsg!,
                style:
                    TextStyle(color: AppColors.neonAccent, fontSize: 13),
              ),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(Icons.close, color: AppColors.neonAccent, size: 16),
              onPressed: () => setState(() => _statusMsg = null),
            ),
          ],
        ),
      ),
    );
  }

  // ── Filters ────────────────────────────────────────────────────────────────

  Widget _buildFilterRow(
    List<AppUser> users,
    List<Map<String, dynamic>> allTrips,
  ) {
    final modes = allTrips
        .map((t) => t['mode'] as String? ?? 'Unknown')
        .toSet()
        .toList()
      ..sort();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          // User filter
          _FilterChip(
            label: _selectedUserId == null
                ? 'All users'
                : _labelForUser(_selectedUserId!),
            active: _selectedUserId != null,
            icon: Icons.person_outline,
            onTap: () => _showUserFilterSheet(users),
          ),
          // Mode filter
          _FilterChip(
            label: _selectedMode ?? 'All modes',
            active: _selectedMode != null,
            icon: Icons.directions_car_outlined,
            onTap: () => _showModeFilterSheet(modes),
          ),
          // Clear
          if (_selectedUserId != null || _selectedMode != null)
            _FilterChip(
              label: 'Clear',
              active: false,
              icon: Icons.clear,
              onTap: () => setState(() {
                _selectedUserId = null;
                _selectedMode = null;
              }),
            ),
        ],
      ),
    );
  }

  String _labelForUser(String userId) {
    try {
      return context.read<AuthService>().getUserById(userId)?.name ?? userId;
    } catch (_) {
      return userId;
    }
  }

  void _showUserFilterSheet(List<AppUser> users) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Filter by User',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                title: const Text(
                  'All users',
                  style: TextStyle(color: Colors.white),
                ),
                selected: _selectedUserId == null,
                selectedColor: AppColors.neonPurple,
                onTap: () {
                  setState(() => _selectedUserId = null);
                  Navigator.pop(context);
                },
              ),
              ...users.map(
                (u) => ListTile(
                  leading: _AvatarCircle(name: u.name, size: 36),
                  title: Text(
                    u.name,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    u.email,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  selected: _selectedUserId == u.userId,
                  selectedColor: AppColors.neonPurple,
                  onTap: () {
                    setState(() => _selectedUserId = u.userId);
                    Navigator.pop(context);
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showModeFilterSheet(List<String> modes) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Filter by Mode',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                title: const Text(
                  'All modes',
                  style: TextStyle(color: Colors.white),
                ),
                selected: _selectedMode == null,
                selectedColor: AppColors.neonPurple,
                onTap: () {
                  setState(() => _selectedMode = null);
                  Navigator.pop(context);
                },
              ),
              ...modes.map(
                (m) => ListTile(
                  title: Text(
                    m,
                    style: const TextStyle(color: Colors.white),
                  ),
                  selected: _selectedMode == m,
                  selectedColor: AppColors.neonPurple,
                  onTap: () {
                    setState(() => _selectedMode = m);
                    Navigator.pop(context);
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  List<Map<String, dynamic>> _applyFilter(
    List<Map<String, dynamic>> trips,
  ) {
    return trips.where((t) {
      if (_selectedUserId != null &&
          (t['userId'] as String? ?? '') != _selectedUserId) {
        return false;
      }
      if (_selectedMode != null &&
          (t['mode'] as String? ?? 'Unknown') != _selectedMode) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) {
        final ta = a['startTime'] as String? ?? '';
        final tb = b['startTime'] as String? ?? '';
        return tb.compareTo(ta); // newest first
      });
  }

  // ── Upload / fetch ─────────────────────────────────────────────────────────

  Future<void> _triggerUpload() async {
    setState(() => _syncing = true);
    try {
      final service = TripSyncService(db: _db);
      final count = await service.uploadPendingTrips();
      setState(() {
        _statusMsg = count > 0
            ? '$count trip${count == 1 ? '' : 's'} uploaded to server.'
            : 'No pending trips to sync.';
      });
    } catch (e) {
      setState(() => _statusMsg = 'Upload failed: $e');
    } finally {
      setState(() => _syncing = false);
    }
  }

  Future<void> _triggerFetch() async {
    setState(() => _fetching = true);
    try {
      final service = TripSyncService(db: _db);
      final trips = await service.downloadAllTrips();
      setState(() {
        _statusMsg = 'Fetched ${trips.length} trip${trips.length == 1 ? '' : 's'} from server.';
      });
      _tabController.animateTo(1);
    } catch (e) {
      setState(() => _statusMsg = 'Fetch failed: $e');
    } finally {
      setState(() => _fetching = false);
    }
  }

  // ── Server data tab ────────────────────────────────────────────────────────

  Widget _buildServerDataTab(AuthService auth) {
    return ValueListenableBuilder(
      valueListenable: _db.serverTripsBox.listenable(),
      builder: (context, _, _) {
        final serverTrips = _db.getServerTrips();

        if (serverTrips.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.cloud_download_outlined,
                  size: 72,
                  color: AppColors.neonPurple.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 18),
                const Text(
                  'No server data yet.',
                  style: TextStyle(color: Colors.white70, fontSize: 17),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap the download icon to fetch all trips from the server.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.neonPurple.withValues(alpha: 0.22),
                    foregroundColor: AppColors.neonPurple,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.cloud_download_outlined, size: 18),
                  label: const Text('Fetch from server'),
                  onPressed: _fetching ? null : _triggerFetch,
                ),
              ],
            ),
          );
        }

        final filtered = _applyFilter(serverTrips);
        final serverUsers = auth.getAllUsers();
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _buildStatsRow(serverTrips, _countDistinctUsers(serverTrips)),
            ),
            SliverToBoxAdapter(child: _buildStatusBanner()),
            SliverToBoxAdapter(child: _buildFilterRow(serverUsers, serverTrips)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  '${filtered.length} of ${serverTrips.length} server trip${serverTrips.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            filtered.isEmpty
                ? SliverFillRemaining(child: _buildEmpty())
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final trip = filtered[index];
                        return Padding(
                          padding: EdgeInsets.fromLTRB(
                            20,
                            index == 0 ? 0 : 8,
                            20,
                            index == filtered.length - 1 ? 32 : 0,
                          ),
                          child: _AdminTripCard(
  trip: trip,
  auth: auth,
  tripKey: trip['key'],
),
                        );
                      },
                      childCount: filtered.length,
                    ),
                  ),
          ],
        );
      },
    );
  }

  int _countDistinctUsers(List<Map<String, dynamic>> trips) {
    return trips.map((t) => t['userId'] as String? ?? '').toSet().length;
  }

  // ── Empty state ────────────────────────────────────────────────────────────

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_rounded, size: 72, color: Colors.white24),
          const SizedBox(height: 18),
          const Text(
            'No trips match the current filter.',
            style: TextStyle(color: Colors.white70, fontSize: 17),
          ),
        ],
      ),
    );
  }

  // ── CSV export ─────────────────────────────────────────────────────────────

  void _exportCsv() {
    final service = TripSyncService(db: _db);
    if (service.endpoint.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No backend endpoint configured. '
            'Run with --dart-define=NATPAC_SYNC_ENDPOINT=http://<host>:3000',
          ),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    final url = '${service.endpoint}/api/trips/export';
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('CSV URL copied: $url'),
        backgroundColor: AppColors.neonAccent.withValues(alpha: 0.9),
        action: SnackBarAction(
          label: 'OK',
          textColor: AppColors.background,
          onPressed: () {},
        ),
      ),
    );
  }

  // ── Logout ─────────────────────────────────────────────────────────────────

  Future<void> _logout(AuthService auth) async {
    await auth.logout();
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
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

// ── Trip card ─────────────────────────────────────────────────────────────────

class _AdminTripCard extends StatelessWidget {
  const _AdminTripCard({
    required this.trip,
    required this.auth,
    this.tripKey,
  });

  final Map<String, dynamic> trip;
  final AuthService auth;
  /// Hive key — only present for local trips. Null for server-fetched trips.
  final dynamic tripKey;

  @override
  Widget build(BuildContext context) {
    final distance = (trip['distance'] as num?)?.toDouble() ?? 0;
    final duration = Duration(
      seconds: (trip['duration'] as num?)?.toInt() ?? 0,
    );
    final mode = trip['mode'] as String? ?? 'Unknown';
    final purpose = trip['purpose'] as String? ?? 'Unknown';
    final userId = trip['userId'] as String? ?? '';
    final userName = userId.isEmpty
        ? 'Unknown user'
        : (auth.getUserById(userId)?.name ?? userId);
    final synced = trip['synced'] == true;
    final startTime = trip['startTime'] as String? ?? '';

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _AvatarCircle(name: userName, size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      startTime.isNotEmpty
                          ? formatDateTime(startTime)
                          : 'Unknown time',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (tripKey != null)
                IconButton(
                  tooltip: 'Edit trip',
                  icon: Icon(Icons.edit_rounded,
                      color: AppColors.neonPurple, size: 20),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TripFormScreen(
                        trip: Trip.fromMap(trip),
                        tripKey: tripKey,
                      ),
                    ),
                  ),
                ),
              _SyncBadge(synced: synced),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _TripMetric(
                label: 'Distance',
                value: formatDistance(distance),
                icon: Icons.route_rounded,
                color: AppColors.neonBlue,
              ),
              const SizedBox(width: 12),
              _TripMetric(
                label: 'Duration',
                value: formatDuration(duration),
                icon: Icons.timer_rounded,
                color: AppColors.neonPurple,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _TripMetric(
                label: 'Mode',
                value: mode,
                icon: Icons.directions_car_rounded,
                color: AppColors.neonAccent,
              ),
              const SizedBox(width: 12),
              _TripMetric(
                label: 'Purpose',
                value: purpose,
                icon: Icons.info_outline,
                color: Colors.orangeAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TripMetric extends StatelessWidget {
  const _TripMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncBadge extends StatelessWidget {
  const _SyncBadge({required this.synced});
  final bool synced;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: synced
            ? Colors.green.withValues(alpha: 0.14)
            : Colors.orangeAccent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            synced ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
            size: 12,
            color: synced ? Colors.green : Colors.orangeAccent,
          ),
          const SizedBox(width: 4),
          Text(
            synced ? 'Synced' : 'Pending',
            style: TextStyle(
              color: synced ? Colors.green : Colors.orangeAccent,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Filter chip ───────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.active,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final bool active;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? AppColors.neonPurple.withValues(alpha: 0.18)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? AppColors.neonPurple.withValues(alpha: 0.6)
                : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: active ? AppColors.neonPurple : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: active ? AppColors.neonPurple : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Avatar circle ─────────────────────────────────────────────────────────────

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({required this.name, required this.size});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(' ').take(2).map((w) => w[0].toUpperCase()).join();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.neonPurple.withValues(alpha: 0.22),
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.neonPurple.withValues(alpha: 0.5),
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: AppColors.neonPurple,
            fontWeight: FontWeight.w800,
            fontSize: size * 0.36,
          ),
        ),
      ),
    );
  }
}
