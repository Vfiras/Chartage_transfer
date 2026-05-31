import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/transport_trip.dart';

/// Reusable bottom-sheet for editing a booking.
/// Pops with `Map<String, dynamic>` payload on save, or `null` on cancel.
class BookingEditSheet extends StatefulWidget {
  final TransportTrip trip;

  const BookingEditSheet({super.key, required this.trip});

  @override
  State<BookingEditSheet> createState() => _BookingEditSheetState();
}

class _BookingEditSheetState extends State<BookingEditSheet> {
  late final TextEditingController _passenger;
  late final TextEditingController _phone;
  late final TextEditingController _pickup;
  late final TextEditingController _destination;
  late final TextEditingController _city;
  late final TextEditingController _vehicle;
  late final TextEditingController _earnings;
  late final TextEditingController _date;
  late final TextEditingController _time;
  late final TextEditingController _pax;
  late final TextEditingController _luggage;
  late String _status;

  // Backend canonical status values — must match VALID_STATUSES in bookings.py
  static const _statuses = [
    ('pending', 'Pending'),
    ('confirmed', 'Confirmed'),
    ('on_route', 'On Route'),
    ('completed', 'Completed'),
    ('cancelled', 'Cancelled'),
  ];

  @override
  void initState() {
    super.initState();
    final t = widget.trip;
    _passenger = TextEditingController(text: t.passengerName);
    _phone = TextEditingController(text: t.passengerPhone);
    _pickup = TextEditingController(text: t.pickupLocation);
    _destination = TextEditingController(text: t.destinationName);
    _city = TextEditingController(text: t.destinationCity);
    _vehicle = TextEditingController(text: t.vehicleClass.isNotEmpty ? t.vehicleClass : t.vehicleType);
    _earnings = TextEditingController(text: t.estimatedEarnings.toStringAsFixed(0));
    _date = TextEditingController(text: t.departureDate);
    _time = TextEditingController(text: t.departureTime.isNotEmpty ? t.departureTime : t.pickupTime);
    _pax = TextEditingController(text: t.passengerCount.toString());
    _luggage = TextEditingController(text: t.luggageCount.toString());
    // Normalise: if the stored status is one of the old values, map to backend value
    _status = _normaliseStatus(t.status);
  }

  static String _normaliseStatus(String raw) {
    return switch (raw) {
      'requested' => 'pending',
      'assigned' || 'started' || 'arrived' || 'contacted' => 'confirmed',
      'rejected' => 'cancelled',
      _ => raw,
    };
  }

  @override
  void dispose() {
    for (final c in [
      _passenger, _phone, _pickup, _destination, _city,
      _vehicle, _earnings, _date, _time, _pax, _luggage,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    Navigator.of(context).pop<Map<String, dynamic>>({
      'passenger_name': _passenger.text.trim(),
      'passenger_phone': _phone.text.trim(),
      'pickup_location': _pickup.text.trim(),
      'destination_name': _destination.text.trim(),
      'destination_city': _city.text.trim(),
      'vehicle_type': _vehicle.text.trim(),
      'vehicle_class': _vehicle.text.trim(),
      'estimated_earnings': double.tryParse(_earnings.text.trim()) ?? 0,
      'departure_date': _date.text.trim(),
      'departure_time': _time.text.trim(),
      'pickup_time': _time.text.trim(),
      'passenger_count': int.tryParse(_pax.text.trim()) ?? 1,
      'luggage_count': int.tryParse(_luggage.text.trim()) ?? 0,
      'status': _status,
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.90),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Center(
              child: Container(
                width: 44, height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD8CCB5),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Edit Booking',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.trip.id,
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 16),

            _Field(label: 'Passenger name', ctrl: _passenger),
            _Field(label: 'Phone', ctrl: _phone, type: TextInputType.phone),
            _Field(label: 'Pickup location', ctrl: _pickup),
            _Field(label: 'Destination', ctrl: _destination),
            _Field(label: 'City', ctrl: _city),
            _Field(label: 'Vehicle', ctrl: _vehicle),
            Row(
              children: [
                Expanded(child: _Field(label: 'Departure date', ctrl: _date, hint: 'YYYY-MM-DD')),
                const SizedBox(width: 10),
                Expanded(child: _Field(label: 'Departure time', ctrl: _time, hint: 'HH:MM')),
              ],
            ),
            Row(
              children: [
                Expanded(child: _Field(label: 'Passengers', ctrl: _pax, type: TextInputType.number)),
                const SizedBox(width: 10),
                Expanded(child: _Field(label: 'Luggage', ctrl: _luggage, type: TextInputType.number)),
              ],
            ),
            _Field(label: 'Earnings (USD)', ctrl: _earnings, type: TextInputType.number),
            const SizedBox(height: 4),

            // Status dropdown — uses backend canonical values
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: _deco('Status'),
              dropdownColor: AppColors.surfaceElevated,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
              items: [
                for (final (val, label) in _statuses)
                  DropdownMenuItem(value: val, child: Text(label)),
              ],
              onChanged: (v) { if (v != null) setState(() => _status = v); },
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
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
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w800)),
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

// ── Helpers ───────────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final TextInputType? type;
  final String? hint;

  const _Field({required this.label, required this.ctrl, this.type, this.hint});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        keyboardType: type,
        style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
        decoration: _deco(label).copyWith(hintText: hint),
      ),
    );
  }
}

InputDecoration _deco(String label) => InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
      filled: true,
      fillColor: AppColors.surfaceElevated,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.secondary, width: 1.5),
      ),
    );
