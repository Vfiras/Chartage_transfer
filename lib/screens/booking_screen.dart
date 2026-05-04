import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/booking_data.dart';
import '../screens/booking_fleet_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/primary_button.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final BookingData _data = BookingData();
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  String _tripType = 'one-way';
  bool _loading = false;

  @override
  void dispose() {
    _pickupController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      _data.date = DateFormat('EEE, MMM d').format(picked);
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked == null) return;
    setState(() {
      _data.time = picked.format(context);
    });
  }

  Future<void> _changePassengers(int delta) async {
    setState(() {
      _data.passengers = (_data.passengers + delta).clamp(1, 8).toInt();
    });
  }

  void _swapLocations() {
    final temp = _pickupController.text;
    _pickupController.text = _destinationController.text;
    _destinationController.text = temp;
    setState(() {});
  }

  Future<void> _continueToFleet() async {
    setState(() {
      _loading = true;
      _data.pickup = _pickupController.text.trim();
      _data.destination = _destinationController.text.trim();
      _data.tripType = _tripType;
    });

    await Future<void>.delayed(const Duration(milliseconds: 180));

    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookingFleetScreen(data: _data),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 28, 16, 36),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AppCard(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                        radius: 28,
                        backgroundColor: AppColors.surface,
                        borderColor: AppColors.border,
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x12000000),
                            blurRadius: 24,
                            offset: Offset(0, 10),
                          ),
                        ],
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'QUICK BOOKING',
                                  style: TextStyle(
                                    color: AppColors.secondary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.6,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Where are you going?',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    height: 1.15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2F2F2),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              children: [
                                _TripTypeChip(
                                  label: 'One Way',
                                  active: _tripType == 'one-way',
                                  onTap: () => setState(() => _tripType = 'one-way'),
                                ),
                                _TripTypeChip(
                                  label: 'Round Trip',
                                  active: _tripType == 'round-trip',
                                  onTap: () => setState(() => _tripType = 'round-trip'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _RouteField(
                        icon: Icons.place_rounded,
                        label: 'Pickup',
                        hintText: 'Hotel, address, terminal...',
                        controller: _pickupController,
                        topTint: AppColors.primary,
                      ),
                      const SizedBox(height: 10),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _RouteField(
                            icon: Icons.navigation_rounded,
                            label: 'Destination',
                            hintText: 'Airport or destination...',
                            controller: _destinationController,
                            isDestination: true,
                            topTint: AppColors.secondary,
                          ),
                          Positioned(
                            right: 10,
                            top: -14,
                            child: GestureDetector(
                              onTap: _swapLocations,
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.border),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x14000000),
                                      blurRadius: 10,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.swap_vert_rounded,
                                  size: 18,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _SmallInfoCard(
                              icon: Icons.calendar_month_rounded,
                              label: 'Date',
                              value: _data.date.isEmpty ? 'Select date' : _data.date,
                              onTap: _pickDate,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _SmallInfoCard(
                              icon: Icons.groups_rounded,
                              label: 'Passengers',
                              value:
                                  '${_data.passengers} person${_data.passengers > 1 ? 's' : ''}',
                              onTap: () => _changePassengers(1),
                              onLongPress: () => _changePassengers(-1),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _SmallInfoCard(
                        icon: Icons.schedule_rounded,
                        label: 'Time',
                        value: _data.time.isEmpty ? 'Select time' : _data.time,
                        onTap: _pickTime,
                      ),
                      const SizedBox(height: 16),
                      PrimaryButton(
                        text: _loading ? 'Opening fleet...' : 'Search & Book',
                        onPressed: _loading ? null : _continueToFleet,
                        trailing: const Icon(Icons.arrow_forward_rounded, size: 18),
                      ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 96),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TripTypeChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TripTypeChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : const Color(0xFF8A8A8A),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _RouteField extends StatelessWidget {
  final IconData icon;
  final String label;
  final String hintText;
  final TextEditingController controller;
  final Color topTint;
  final bool isDestination;

  const _RouteField({
    required this.icon,
    required this.label,
    required this.hintText,
    required this.controller,
    required this.topTint,
    this.isDestination = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: isDestination ? AppColors.chipGoldBg : const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDestination ? const Color(0x2EE6A200) : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: topTint,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                TextField(
                  controller: controller,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    height: 1.3,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.only(top: 3),
                    border: InputBorder.none,
                    hintText: hintText,
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFFB7B7B7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}

class _SmallInfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _SmallInfoCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.secondary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
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
