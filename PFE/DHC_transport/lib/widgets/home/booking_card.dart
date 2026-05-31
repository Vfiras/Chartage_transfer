import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/language_service.dart';
import '../../core/services/pricing_service.dart';
import '../../models/booking_data.dart';
import '../../shared/widgets/common/luxury_components.dart';

class BookingCard extends StatefulWidget {
  final ValueChanged<BookingData> onSearch;

  const BookingCard({super.key, required this.onSearch});

  @override
  State<BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends State<BookingCard> {
  final _pickup = TextEditingController();
  final _destination = TextEditingController();
  final _promo = TextEditingController();
  PricingRules _rules = const PricingRules();
  String _tripType = 'one-way';
  DateTime? _departureDate;
  TimeOfDay? _departureTime;
  DateTime? _returnDate;
  TimeOfDay? _returnTime;
  int _passengers = 1;
  int _luggage = 1;

  @override
  void initState() {
    super.initState();
    _loadRules();
    _pickup.addListener(_refresh);
    _destination.addListener(_refresh);
    _promo.addListener(_refresh);
  }

  Future<void> _loadRules() async {
    final rules = await const PricingService().rules();
    if (mounted) setState(() => _rules = rules);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _pickup.dispose();
    _destination.dispose();
    _promo.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isReturn}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (isReturn) {
        _returnDate = picked;
      } else {
        _departureDate = picked;
      }
    });
  }

  Future<void> _pickTime({required bool isReturn}) async {
    final picked =
        await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked == null) return;
    setState(() {
      if (isReturn) {
        _returnTime = picked;
      } else {
        _departureTime = picked;
      }
    });
  }

  void _submit() {
    final l = LanguageService.instance;
    if (_pickup.text.trim().isEmpty || _destination.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.t('booking_pickup_destination_required'))),
      );
      return;
    }
    if (_departureDate == null || _departureTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.t('booking_time_required'))),
      );
      return;
    }
    if (_tripType == 'round-trip' &&
        (_returnDate == null || _returnTime == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.t('booking_return_required'))),
      );
      return;
    }
    final data = _data();
    if (!const PricingService().respectsMinimumBooking(data, _rules)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l.t(
              'booking_minimum',
              args: {'hours': _rules.minimumBookingHours},
            ),
          ),
        ),
      );
      return;
    }
    widget.onSearch(
      data,
    );
  }

  BookingData _data() {
    return BookingData(
      pickup: _pickup.text.trim(),
      destination: _destination.text.trim(),
      tripType: _tripType,
      departureDate: _departureDate == null
          ? ''
          : DateFormat('yyyy-MM-dd').format(_departureDate!),
      departureTime: _departureTime?.format(context) ?? '',
      returnDate: _returnDate == null
          ? ''
          : DateFormat('yyyy-MM-dd').format(_returnDate!),
      returnTime: _returnTime?.format(context) ?? '',
      passengers: _passengers,
      luggageCount: _luggage,
      promoCode: _promo.text.trim().toUpperCase(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;

    return LuxuryCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.goldBorder),
                ),
                child: Icon(Icons.flight_takeoff_rounded,
                    color: AppColors.secondary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.t('book_transfer'),
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w900)),
                    SizedBox(height: 2),
                    Text(l.t('premium_rides'),
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _LocationField(
            controller: _pickup,
            label: l.t('pickup_location'),
            hint: 'Tunis-Carthage Airport',
            icon: Icons.my_location_rounded,
            color: AppColors.green,
          ),
          const SizedBox(height: 12),
          _LocationField(
            controller: _destination,
            label: l.t('destination'),
            hint: l.t('destination_hint'),
            icon: Icons.location_on_rounded,
            color: AppColors.secondary,
          ),
          const SizedBox(height: 14),
          _TripToggle(
            value: _tripType,
            onChanged: (value) => setState(() => _tripType = value),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _PickerTile(
                  icon: Icons.calendar_month_rounded,
                  label: l.t('departure'),
                  value: _dateLabel(_departureDate),
                  onTap: () => _pickDate(isReturn: false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PickerTile(
                  icon: Icons.schedule_rounded,
                  label: l.t('time'),
                  value: _timeLabel(_departureTime),
                  onTap: () => _pickTime(isReturn: false),
                ),
              ),
            ],
          ),
          if (_tripType == 'round-trip') ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _PickerTile(
                    icon: Icons.event_repeat_rounded,
                    label: l.t('return'),
                    value: _dateLabel(_returnDate),
                    onTap: () => _pickDate(isReturn: true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PickerTile(
                    icon: Icons.access_time_rounded,
                    label: l.t('return_time'),
                    value: _timeLabel(_returnTime),
                    onTap: () => _pickTime(isReturn: true),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          _PassengerStepper(
            icon: Icons.groups_rounded,
            label: l.t('passengers'),
            value: _passengers,
            onChanged: (value) => setState(() => _passengers = value),
          ),
          const SizedBox(height: 10),
          _PassengerStepper(
            icon: Icons.luggage_rounded,
            label: l.t('luggage'),
            value: _luggage,
            onChanged: (value) => setState(() => _luggage = value),
          ),
          const SizedBox(height: 10),
          _PromoField(controller: _promo),
          const SizedBox(height: 16),
          LuxuryButton(
            text: l.t('search_book'),
            onPressed: _submit,
            icon: Icon(Icons.arrow_forward_rounded, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  String _dateLabel(DateTime? date) => date == null
      ? LanguageService.instance.t('select')
      : DateFormat('MMM d, yyyy').format(date);
  String _timeLabel(TimeOfDay? time) => time == null
      ? LanguageService.instance.t('select')
      : time.format(context);
}

class _LocationField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final Color color;

  const _LocationField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(),
                    style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w900)),
                TextField(
                  controller: controller,
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    hintText: hint,
                    hintStyle:
                        TextStyle(color: AppColors.textHint, fontSize: 13),
                    contentPadding: const EdgeInsets.only(top: 3),
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.add_rounded, color: AppColors.textMuted, size: 20),
        ],
      ),
    );
  }
}

class _TripToggle extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _TripToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _item('one-way', l.t('one_way')),
          _item('round-trip', l.t('round_trip')),
        ],
      ),
    );
  }

  Widget _item(String itemValue, String label) {
    final active = value == itemValue;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(itemValue),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.secondary : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? AppColors.primary : AppColors.textSecondary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _PickerTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final waiting = value == LanguageService.instance.t('select');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.goldBorder),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.secondary, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label.toUpperCase(),
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text(value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: waiting
                            ? AppColors.secondary
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PassengerStepper extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _PassengerStepper({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.secondary),
          const SizedBox(width: 10),
          Expanded(
              child:
                  Text(label, style: TextStyle(fontWeight: FontWeight.w900))),
          IconButton(
            onPressed: value <= 1 ? null : () => onChanged(value - 1),
            icon: Icon(Icons.remove_circle_outline_rounded),
            color: AppColors.textSecondary,
          ),
          Text('$value',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          IconButton(
            onPressed: () => onChanged(value + 1),
            icon: Icon(Icons.add_circle_outline_rounded),
            color: AppColors.secondary,
          ),
        ],
      ),
    );
  }
}

class _PromoField extends StatelessWidget {
  final TextEditingController controller;

  const _PromoField({required this.controller});

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.local_offer_outlined, color: AppColors.secondary),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              textCapitalization: TextCapitalization.characters,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                hintText: l.t('promo_code'),
                hintStyle: TextStyle(color: AppColors.textHint, fontSize: 13),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
