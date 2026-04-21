import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/home_data.dart';
import '../models/booking_data.dart';
import '../theme/app_colors.dart';
import '../widgets/common/fallback_network_image.dart';
import '../widgets/common/primary_button.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  int step = 1;
  final data = BookingData();

  final pickup = TextEditingController();
  final destination = TextEditingController();

  @override
  void dispose() {
    pickup.dispose();
    destination.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (step == 6) return _success();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _progressHeader(),
              const SizedBox(height: 14),
              if (step == 1) _stepRoute(),
              if (step == 2) _stepDatePax(),
              if (step == 3) _stepService(),
              if (step == 4) _stepVehicle(),
              if (step == 5) _stepReview(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _progressHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
            children: List.generate(5, (i) {
          final on = i < step;
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: i == 4 ? 0 : 4),
              decoration: BoxDecoration(
                color: on ? AppColors.secondaryLight : const Color(0x22000000),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          );
        })),
        const SizedBox(height: 10),
        Text('Step $step of 5',
            style: const TextStyle(
                color: AppColors.secondary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.8)),
      ],
    );
  }

  Widget _stepRoute() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Where are you going?',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        _input(pickup, 'Pickup', Icons.place_rounded),
        const SizedBox(height: 8),
        _input(destination, 'Destination', Icons.navigation_rounded),
        const SizedBox(height: 16),
        PrimaryButton(
          text: 'Continue →',
          onPressed: () {
            data.pickup = pickup.text;
            data.destination = destination.text;
            setState(() => step = 2);
          },
        ),
      ],
    );
  }

  Widget _stepDatePax() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('When & how many?',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        _pickerRow('Date', data.date.isEmpty ? 'Select date' : data.date,
            Icons.calendar_today_rounded, () async {
          final d = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime.now().subtract(const Duration(days: 1)),
            lastDate: DateTime.now().add(const Duration(days: 365)),
          );
          if (d != null) {
            setState(() => data.date = DateFormat('yyyy-MM-dd').format(d));
          }
        }),
        const SizedBox(height: 8),
        _pickerRow('Time', data.time.isEmpty ? 'Select time' : data.time,
            Icons.schedule_rounded, () async {
          final t = await showTimePicker(
              context: context, initialTime: TimeOfDay.now());
          if (t != null) setState(() => data.time = t.format(context));
        }),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
              color: const Color(0xFFF8F8F8),
              borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: [
              const Icon(Icons.groups_rounded, color: AppColors.secondary),
              const SizedBox(width: 10),
              Text('${data.passengers} passenger(s)',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(
                onPressed: () => setState(() => data.passengers =
                    data.passengers > 1 ? data.passengers - 1 : 1),
                icon: const Icon(Icons.remove_circle_outline_rounded),
              ),
              IconButton(
                onPressed: () => setState(() => data.passengers++),
                icon: const Icon(Icons.add_circle_outline_rounded),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PrimaryButton(
            text: 'Continue →', onPressed: () => setState(() => step = 3)),
      ],
    );
  }

  Widget _stepService() {
    const services = [
      'airport',
      'chauffeur',
      'group',
      'business',
      'tours',
      'access'
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Choose service',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: services.map((s) {
            final on = data.serviceId == s;
            return GestureDetector(
              onTap: () => setState(() => data.serviceId = s),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: on ? const Color(0x26FFB400) : AppColors.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                      color: on ? AppColors.secondary : AppColors.softBorder),
                ),
                child: Text(s.toUpperCase(),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: on
                            ? AppColors.textPrimary
                            : AppColors.textSecondary)),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        PrimaryButton(
            text: 'Continue →', onPressed: () => setState(() => step = 4)),
      ],
    );
  }

  Widget _stepVehicle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Choose vehicle',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        ...HomeData.vehicles.map((v) {
          final on = data.vehicleId == v.id;
          return GestureDetector(
            onTap: () => setState(() => data.vehicleId = v.id),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: on ? AppColors.secondary : AppColors.softBorder),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: FallbackNetworkImage(
                        url: v.image, width: 90, height: 68, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(v.name,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w800)),
                          Text(v.model,
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.textMuted)),
                          const SizedBox(height: 4),
                          Text('${v.price} TND',
                              style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.secondary,
                                  fontWeight: FontWeight.w800)),
                        ]),
                  ),
                  if (on)
                    const Icon(Icons.check_circle_rounded,
                        color: AppColors.secondary),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 12),
        PrimaryButton(
            text: 'Review Booking →',
            onPressed: () => setState(() => step = 5)),
      ],
    );
  }

  Widget _stepReview() {
    final vehicle = HomeData.vehicles.firstWhere((e) => e.id == data.vehicleId,
        orElse: () => HomeData.vehicles.first);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Booking summary',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.softBorder),
          ),
          child: Column(
            children: [
              ListTile(
                  title: const Text('Pickup'), trailing: Text(data.pickup)),
              ListTile(
                  title: const Text('Destination'),
                  trailing: Text(data.destination)),
              ListTile(title: const Text('Date'), trailing: Text(data.date)),
              ListTile(title: const Text('Time'), trailing: Text(data.time)),
              ListTile(
                  title: const Text('Passengers'),
                  trailing: Text('${data.passengers}')),
              ListTile(
                  title: const Text('Vehicle'), trailing: Text(vehicle.name)),
              ListTile(
                title: const Text('Total',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                trailing: Text('${vehicle.price} TND',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.secondary)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        PrimaryButton(
            text: 'Confirm Booking', onPressed: () => setState(() => step = 6)),
      ],
    );
  }

  Widget _success() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [
                      AppColors.secondaryLight,
                      AppColors.secondary
                    ]),
                  ),
                  child: const Icon(Icons.check_rounded,
                      size: 46, color: AppColors.primary),
                ),
                const SizedBox(height: 14),
                const Text('Booking Confirmed!',
                    style:
                        TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(
                    'Reference: CT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _input(TextEditingController c, String h, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
          color: const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(icon, color: AppColors.secondary),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: c,
              decoration:
                  InputDecoration(hintText: h, border: InputBorder.none),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pickerRow(
      String label, String value, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
            color: const Color(0xFFF8F8F8),
            borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Icon(icon, color: AppColors.secondary),
            const SizedBox(width: 10),
            Expanded(
                child: Text('$label: $value',
                    style: const TextStyle(fontWeight: FontWeight.w700))),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}
