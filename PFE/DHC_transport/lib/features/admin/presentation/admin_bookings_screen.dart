import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/admin_booking.dart';
import '../../../core/models/transport_trip.dart';
import '../../../core/services/trip_service.dart';
import '../../../shared/widgets/admin/booking_card.dart';

class AdminBookingsScreen extends StatefulWidget {
  final ValueChanged<AdminBooking> onOpenBookingDetails;

  const AdminBookingsScreen({
    super.key,
    required this.onOpenBookingDetails,
  });

  @override
  State<AdminBookingsScreen> createState() => _AdminBookingsScreenState();
}

class _AdminBookingsScreenState extends State<AdminBookingsScreen> {
  final _service = const TripService();
  late Future<List<TransportTrip>> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _service.listTrips();
  }

  void _reload() {
    setState(() {
      _future = _service.listTrips();
    });
  }

  Future<void> _delete(TransportTrip trip) async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete booking?'),
        content: Text('This will permanently delete ${trip.id} from MongoDB.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await _service.deleteBooking(trip.id);
      if (!mounted) return;
      _reload();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(TransportTrip trip) async {
    if (_busy) return;
    final payload = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BookingEditSheet(trip: trip),
    );
    if (payload == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await _service.updateTrip(trip.id, payload);
      if (!mounted) return;
      _reload();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 130),
              children: [
                const Text(
                  'Bookings',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Review trips, edit fields, and delete records from MongoDB.',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                FutureBuilder<List<TransportTrip>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(28),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return _InfoCard(
                          title: 'Backend unavailable',
                          subtitle: snapshot.error.toString());
                    }
                    final trips = snapshot.data ?? const <TransportTrip>[];
                    if (trips.isEmpty) {
                      return const _InfoCard(
                        title: 'No bookings',
                        subtitle:
                            'Trips created from the backend will appear here.',
                      );
                    }
                    return Column(
                      children: [
                        for (final trip in trips) ...[
                          BookingCard(
                            booking: AdminBooking.fromTrip(trip),
                            onViewDetails: () => widget.onOpenBookingDetails(
                                AdminBooking.fromTrip(trip)),
                            onEdit: () => _edit(trip),
                            onDelete: () => _delete(trip),
                          ),
                          const SizedBox(height: 14),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          if (_busy)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.45),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}

class _BookingEditSheet extends StatefulWidget {
  final TransportTrip trip;

  const _BookingEditSheet({required this.trip});

  @override
  State<_BookingEditSheet> createState() => _BookingEditSheetState();
}

class _BookingEditSheetState extends State<_BookingEditSheet> {
  late final TextEditingController _passengerController;
  late final TextEditingController _phoneController;
  late final TextEditingController _pickupController;
  late final TextEditingController _destinationController;
  late final TextEditingController _cityController;
  late final TextEditingController _vehicleController;
  late final TextEditingController _earningsController;
  late final TextEditingController _timeController;
  late String _status;

  @override
  void initState() {
    super.initState();
    final trip = widget.trip;
    _passengerController = TextEditingController(text: trip.passengerName);
    _phoneController = TextEditingController(text: trip.passengerPhone);
    _pickupController = TextEditingController(text: trip.pickupLocation);
    _destinationController = TextEditingController(text: trip.destinationName);
    _cityController = TextEditingController(text: trip.destinationCity);
    _vehicleController = TextEditingController(text: trip.vehicleType);
    _earningsController =
        TextEditingController(text: trip.estimatedEarnings.toStringAsFixed(0));
    _timeController = TextEditingController(text: trip.pickupTime);
    _status = trip.status;
  }

  @override
  void dispose() {
    _passengerController.dispose();
    _phoneController.dispose();
    _pickupController.dispose();
    _destinationController.dispose();
    _cityController.dispose();
    _vehicleController.dispose();
    _earningsController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.of(context).pop({
      'passenger_name': _passengerController.text.trim(),
      'passenger_phone': _phoneController.text.trim(),
      'pickup_location': _pickupController.text.trim(),
      'destination_name': _destinationController.text.trim(),
      'destination_city': _cityController.text.trim(),
      'vehicle_type': _vehicleController.text.trim(),
      'estimated_earnings':
          double.tryParse(_earningsController.text.trim()) ?? 0,
      'pickup_time': _timeController.text.trim(),
      'status': _status,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD8CCB5),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Edit Booking',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            _EditField(label: 'Passenger', controller: _passengerController),
            _EditField(label: 'Phone', controller: _phoneController),
            _EditField(label: 'Pickup', controller: _pickupController),
            _EditField(
                label: 'Destination', controller: _destinationController),
            _EditField(label: 'City', controller: _cityController),
            _EditField(label: 'Vehicle', controller: _vehicleController),
            _EditField(
              label: 'Earnings',
              controller: _earningsController,
              keyboardType: TextInputType.number,
            ),
            _EditField(label: 'Pickup time', controller: _timeController),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: _inputDecoration('Status'),
              items: const [
                DropdownMenuItem(value: 'requested', child: Text('Requested')),
                DropdownMenuItem(value: 'assigned', child: Text('Assigned')),
                DropdownMenuItem(value: 'started', child: Text('Started')),
                DropdownMenuItem(value: 'arrived', child: Text('Arrived')),
                DropdownMenuItem(value: 'completed', child: Text('Completed')),
                DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _status = value);
              },
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: AppColors.primary,
                    ),
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;

  const _EditField({
    required this.label,
    required this.controller,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: _inputDecoration(label),
      ),
    );
  }
}

InputDecoration _inputDecoration(String label) {
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: AppColors.surfaceElevated,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.border),
    ),
  );
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const _InfoCard({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
