import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/language_service.dart';
import 'ava_booking_fields.dart';

/// Collects a whole booking in ONE card inside the chat.
///
/// AVA used to gather this field by field — date, then year, then passengers,
/// then vehicle — six or more turns before anything happened. This asks for all
/// of it at once with pickers and counters, then hands the caller a single
/// complete sentence to send, so AVA has nothing left to ask.
///
/// Nothing here talks to the network: it formats a message and calls back.
class BookingFormCard extends StatefulWidget {
  final String? initialPickup;
  final String? initialDestination;
  final void Function(String formattedMessage) onSubmit;

  const BookingFormCard({
    super.key,
    this.initialPickup,
    this.initialDestination,
    required this.onSubmit,
  });

  @override
  State<BookingFormCard> createState() => _BookingFormCardState();
}

class _BookingFormCardState extends State<BookingFormCard> {
  late String? _pickup = widget.initialPickup;
  late String? _destination = widget.initialDestination;
  DateTime? _date;
  TimeOfDay? _time;
  int _passengers = 1;
  int _luggage = 1;
  String? _vehicle;

  /// Locked once submitted so the card cannot be sent twice from scrollback.
  bool _submitted = false;

  bool get _complete =>
      (_pickup?.trim().isNotEmpty ?? false) &&
      (_destination?.trim().isNotEmpty ?? false) &&
      _date != null &&
      _time != null &&
      _vehicle != null;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
                primary: AppColors.secondary,
                onPrimary: const Color(0xFF141313),
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 10, minute: 0),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
                primary: AppColors.secondary,
                onPrimary: const Color(0xFF141313),
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) setState(() => _time = picked);
  }

  Future<void> _editPlace({required bool isPickup}) async {
    final l = LanguageService.instance;
    final controller = TextEditingController(
        text: (isPickup ? _pickup : _destination) ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          isPickup ? l.t('ava_bf_pickup') : l.t('ava_bf_destination'),
          style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(hintText: l.t('ava_bf_place_hint')),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(l.t('ava_bf_set'),
                style: TextStyle(color: AppColors.secondary)),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (isPickup) {
        _pickup = result.isEmpty ? null : result;
      } else {
        _destination = result.isEmpty ? null : result;
      }
    });
  }

  void _submit() {
    if (!_complete || _submitted) return;
    final message = AvaBookingFields(
      pickup: _pickup!,
      destination: _destination!,
      date: _date!,
      time: _time!,
      passengers: _passengers,
      luggage: _luggage,
      vehicle: _vehicle!,
    ).toRequestSentence();
    setState(() => _submitted = true);
    widget.onSubmit(message);
  }

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;
    return AvaFormShell(
      title: l.t('ava_bf_title'),
      children: [
        _PlaceRow(
          label: l.t('ava_bf_from'),
          value: _pickup,
          enabled: !_submitted,
          onTap: () => _editPlace(isPickup: true),
        ),
        const SizedBox(height: 10),
        _PlaceRow(
          label: l.t('ava_bf_to'),
          value: _destination,
          enabled: !_submitted,
          onTap: () => _editPlace(isPickup: false),
        ),
        const SizedBox(height: 16),
        AvaPickerRow(
          icon: Icons.calendar_today_rounded,
          label: l.t('ava_bf_date'),
          value: _date == null
              ? null
              : DateFormat('d MMM yyyy').format(_date!),
          placeholder: l.t('ava_bf_select'),
          enabled: !_submitted,
          onTap: _pickDate,
        ),
        const SizedBox(height: 10),
        AvaPickerRow(
          icon: Icons.schedule_rounded,
          label: l.t('ava_bf_time'),
          value: _time == null ? null : _formatTime(_time!),
          placeholder: l.t('ava_bf_select'),
          enabled: !_submitted,
          onTap: _pickTime,
        ),
        const SizedBox(height: 16),
        AvaCounterRow(
          icon: Icons.people_alt_rounded,
          label: l.t('ava_bf_passengers'),
          value: _passengers,
          min: 1,
          max: 12,
          enabled: !_submitted,
          onChanged: (v) => setState(() => _passengers = v),
        ),
        const SizedBox(height: 8),
        AvaCounterRow(
          icon: Icons.luggage_rounded,
          label: l.t('ava_bf_luggage'),
          value: _luggage,
          min: 0,
          max: 10,
          enabled: !_submitted,
          onChanged: (v) => setState(() => _luggage = v),
        ),
        const SizedBox(height: 16),
        AvaSectionLabel(text: l.t('ava_bf_vehicle')),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final v in kAvaVehicleTypes)
              AvaChoiceChip(
                label: v,
                selected: _vehicle == v,
                enabled: !_submitted,
                onTap: () => setState(() => _vehicle = v),
              ),
          ],
        ),
        const SizedBox(height: 18),
        AvaPrimaryButton(
          label: _submitted ? l.t('ava_bf_sent') : l.t('ava_bf_submit'),
          icon: _submitted ? Icons.check_rounded : Icons.place_rounded,
          enabled: _complete && !_submitted,
          onTap: _submit,
        ),
        if (!_complete && !_submitted) ...[
          const SizedBox(height: 8),
          Text(
            l.t('ava_bf_incomplete'),
            style: TextStyle(color: AppColors.textMuted, fontSize: 11.5),
          ),
        ],
      ],
    );
  }

  static String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

// ─── From / To row ───────────────────────────────────────────────────────────

class _PlaceRow extends StatelessWidget {
  final String label;
  final String? value;
  final bool enabled;
  final VoidCallback onTap;

  const _PlaceRow({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;
    final filled = value != null && value!.trim().isNotEmpty;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          SizedBox(
            width: 46,
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: filled
                      ? AppColors.secondary.withValues(alpha: 0.45)
                      : AppColors.border,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    filled ? Icons.check_circle_rounded : Icons.add_location_alt_outlined,
                    size: 15,
                    color: filled ? AppColors.green : AppColors.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      filled ? value! : l.t('ava_bf_tap_enter'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: filled
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                        fontSize: 13.5,
                        fontWeight:
                            filled ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
