import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../modules/storage/local_db.dart';
import '../../modules/trip/trip_model.dart';
import '../../ui/widgets/glass_card.dart';

class TripFormScreen extends StatefulWidget {
  final Trip trip;
  final dynamic tripKey;

  const TripFormScreen({super.key, required this.trip, required this.tripKey});

  @override
  State<TripFormScreen> createState() => _TripFormScreenState();
}

class _TripFormScreenState extends State<TripFormScreen> {
  final LocalDB db = LocalDB();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController costController = TextEditingController();
  final TextEditingController companionsController = TextEditingController();

  String mode = 'Car';
  String purpose = 'Work';
  String frequency = 'Daily';

  @override
  void initState() {
    super.initState();
    mode = widget.trip.mode != 'Unknown' ? widget.trip.mode : 'Car';
    if (mode == 'Bike') mode = 'Motorcycle';
    purpose = widget.trip.purpose != 'Unknown' ? widget.trip.purpose : 'Work';
    frequency = widget.trip.frequency != 'Unknown'
        ? widget.trip.frequency
        : 'Daily';
    costController.text = widget.trip.cost != '0' ? widget.trip.cost : '';
    companionsController.text = widget.trip.companions != '0'
        ? widget.trip.companions
        : '';
  }

  @override
  void dispose() {
    costController.dispose();
    companionsController.dispose();
    super.dispose();
  }

  void saveDetails() {
    if (!_formKey.currentState!.validate()) return;

    db.updateTrip(widget.tripKey, {
      'mode': mode,
      'modeSource': 'manual',
      'modeConfidence': widget.trip.modeConfidence,
      'purpose': purpose,
      'cost': costController.text.trim(),
      'companions': companionsController.text.trim(),
      'frequency': frequency,
    });

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Trip details saved successfully.',
          style: TextStyle(color: AppColors.background),
        ),
        backgroundColor: AppColors.neonBlue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Complete Trip Details'), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tell us more about your trip',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Share the trip purpose, cost, companions and frequency for travel research.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Trip Summary',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildRow('From', widget.trip.startLocation),
                  const SizedBox(height: 12),
                  _buildRow('To', widget.trip.endLocation),
                  const SizedBox(height: 12),
                  _buildRow('Distance', formatDistance(widget.trip.distance)),
                  const SizedBox(height: 12),
                  _buildRow('Duration', formatDuration(widget.trip.duration)),
                  const SizedBox(height: 12),
                  _buildRow(
                    'Traffic delay',
                    formatDuration(widget.trip.trafficDelayDuration),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildDropdown(
                    'Mode of Transport',
                    mode,
                    [
                      'Car',
                      'Motorcycle',
                      'Bus',
                      'Heavy vehicle',
                      'Train',
                      'Walk',
                    ],
                    (value) => setState(() => mode = value!),
                  ),
                  const SizedBox(height: 18),
                  _buildDropdown(
                    'Trip Purpose',
                    purpose,
                    ['Work', 'Home', 'Shopping', 'Leisure', 'Education'],
                    (value) => setState(() => purpose = value!),
                  ),
                  const SizedBox(height: 18),
                  _buildTextField('Travel Cost', costController, 'Enter cost'),
                  const SizedBox(height: 18),
                  _buildTextField(
                    'Companions',
                    companionsController,
                    'Number of companions',
                    numeric: true,
                  ),
                  const SizedBox(height: 18),
                  _buildDropdown(
                    'Frequency',
                    frequency,
                    ['Daily', 'Weekly', 'Occasional', 'First time'],
                    (value) => setState(() => frequency = value!),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: saveDetails,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.neonBlue,
                  foregroundColor: Colors.black,
                ),
                child: const Text(
                  'Save Trip',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Row(
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
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    String hint, {
    bool numeric = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      validator: (value) => value == null || value.trim().isEmpty
          ? 'This field is required'
          : null,
    );
  }

  Widget _buildDropdown(
    String label,
    String current,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: current,
        decoration: const InputDecoration(border: InputBorder.none),
        dropdownColor: AppColors.surface,
        style: const TextStyle(color: Colors.white),
        iconEnabledColor: AppColors.neonBlue,
        onChanged: onChanged,
        items: options
            .map(
              (value) => DropdownMenuItem(
                value: value,
                child: Text(value, style: const TextStyle(color: Colors.white)),
              ),
            )
            .toList(),
      ),
    );
  }
}
