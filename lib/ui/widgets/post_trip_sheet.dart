import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../modules/storage/local_db.dart';
import '../../modules/trip/trip_model.dart';

/// Shows a bottom sheet immediately after a trip ends asking the user
/// to fill in purpose, mode, cost, companions and frequency.
Future<void> showPostTripSheet(
  BuildContext context, {
  required dynamic tripKey,
  required LocalDB db,
}) async {
  final tripMap = db.box.get(tripKey);
  if (tripMap == null || tripMap is! Map) return;
  final trip = Trip.fromMap(Map<String, dynamic>.from(tripMap));

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => _PostTripSheet(tripKey: tripKey, trip: trip, db: db),
  );
}

class _PostTripSheet extends StatefulWidget {
  const _PostTripSheet({
    required this.tripKey,
    required this.trip,
    required this.db,
  });

  final dynamic tripKey;
  final Trip trip;
  final LocalDB db;

  @override
  State<_PostTripSheet> createState() => _PostTripSheetState();
}

class _PostTripSheetState extends State<_PostTripSheet> {
  final _formKey = GlobalKey<FormState>();
  final _costController = TextEditingController();
  final _companionsController = TextEditingController();

  late String _mode;
  String _purpose = 'Work';
  String _frequency = 'Daily';

  static const _modes = [
    'Car', 'Motorcycle', 'Bus', 'Heavy vehicle', 'Train', 'Walk'
  ];
  static const _purposes = [
    'Work', 'Home', 'Shopping', 'Leisure', 'Education'
  ];
  static const _frequencies = [
    'Daily', 'Weekly', 'Occasional', 'First time'
  ];

  @override
  void initState() {
    super.initState();
    final rawMode = widget.trip.mode;
    _mode = _modes.contains(rawMode) ? rawMode : 'Car';
  }

  @override
  void dispose() {
    _costController.dispose();
    _companionsController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    widget.db.updateTrip(widget.tripKey, {
      'mode': _mode,
      'modeSource': 'manual',
      'purpose': _purpose,
      'cost': _costController.text.trim().isEmpty
          ? '0'
          : _costController.text.trim(),
      'companions': _companionsController.text.trim().isEmpty
          ? '0'
          : _companionsController.text.trim(),
      'frequency': _frequency,
    });
    Navigator.pop(context);
  }

  void _skipForNow() => Navigator.pop(context);

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: AppColors.neonPurple.withValues(alpha: 0.4)),
        ),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomPadding),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Header
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.neonPurple.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.flag_rounded,
                      color: AppColors.neonPurple, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Trip completed!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${formatDistance(widget.trip.distance)}  ·  ${formatDuration(widget.trip.duration)}',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 54),
              child: Text(
                'Help NATPAC research by sharing a few trip details.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 24),

            Form(
              key: _formKey,
              child: Column(
                children: [
                  _DropdownField(
                    label: 'Mode of Transport',
                    value: _mode,
                    items: _modes,
                    onChanged: (v) => setState(() => _mode = v!),
                  ),
                  const SizedBox(height: 14),
                  _DropdownField(
                    label: 'Trip Purpose',
                    value: _purpose,
                    items: _purposes,
                    onChanged: (v) => setState(() => _purpose = v!),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _TextField(
                          label: 'Cost (₹)',
                          controller: _costController,
                          hint: '0',
                          numeric: true,
                          required: false,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _TextField(
                          label: 'Companions',
                          controller: _companionsController,
                          hint: '0',
                          numeric: true,
                          required: false,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _DropdownField(
                    label: 'How often do you make this trip?',
                    value: _frequency,
                    items: _frequencies,
                    onChanged: (v) => setState(() => _frequency = v!),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.neonPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Save Trip Details',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _skipForNow,
                child: Text(
                  'Skip for now',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.panel,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      dropdownColor: AppColors.surface,
      style: const TextStyle(color: Colors.white),
      iconEnabledColor: AppColors.neonPurple,
      onChanged: onChanged,
      items: items
          .map((v) => DropdownMenuItem(
                value: v,
                child: Text(v, style: const TextStyle(color: Colors.white)),
              ))
          .toList(),
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.label,
    required this.controller,
    required this.hint,
    this.numeric = false,
    this.required = true,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final bool numeric;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.panel,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        labelStyle: TextStyle(color: AppColors.textSecondary),
      ),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
          : null,
    );
  }
}
