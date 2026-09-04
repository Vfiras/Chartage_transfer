import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/language_service.dart';
import 'ava_booking_fields.dart';

/// Pick a booking, pick what to change, change it — in one card.
///
/// Replaces the text round-trip where AVA listed bookings, waited for a
/// number, then asked what to change, then waited again.
class ModifyBookingCard extends StatefulWidget {
  final List<Map<String, dynamic>> bookings;
  final void Function(String formattedMessage) onSubmit;

  const ModifyBookingCard({
    super.key,
    required this.bookings,
    required this.onSubmit,
  });

  @override
  State<ModifyBookingCard> createState() => _ModifyBookingCardState();
}

enum _Field { date, time, passengers }

class _ModifyBookingCardState extends State<ModifyBookingCard> {
  String? _selectedId;
  final _active = <_Field>{};
  DateTime? _date;
  TimeOfDay? _time;
  int _passengers = 1;
  bool _submitted = false;

  /// A field counts as a change only once it actually holds a value —
  /// revealing the passenger stepper alone must not enable Save.
  bool get _hasChange =>
      (_active.contains(_Field.date) && _date != null) ||
      (_active.contains(_Field.time) && _time != null) ||
      _active.contains(_Field.passengers);

  bool get _canSave => _selectedId != null && _hasChange && !_submitted;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx)
              .colorScheme
              .copyWith(primary: AppColors.secondary,
                        onPrimary: const Color(0xFF141313)),
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
          colorScheme: Theme.of(ctx)
              .colorScheme
              .copyWith(primary: AppColors.secondary,
                        onPrimary: const Color(0xFF141313)),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) setState(() => _time = picked);
  }

  void _toggle(_Field f) {
    setState(() {
      if (_active.contains(f)) {
        _active.remove(f);
        if (f == _Field.date) _date = null;
        if (f == _Field.time) _time = null;
      } else {
        _active.add(f);
      }
    });
  }

  void _submit() {
    if (!_canSave) return;
    final parts = <String>[];
    if (_active.contains(_Field.date) && _date != null) {
      parts.add('date to ${DateFormat('yyyy-MM-dd').format(_date!)}');
    }
    if (_active.contains(_Field.time) && _time != null) {
      parts.add('time to ${_time!.hour.toString().padLeft(2, '0')}:'
          '${_time!.minute.toString().padLeft(2, '0')}');
    }
    if (_active.contains(_Field.passengers)) {
      parts.add('passenger count to $_passengers');
    }
    setState(() => _submitted = true);
    widget.onSubmit(
      'Modify booking $_selectedId: change ${parts.join(', ')}. '
      'Confirm and apply.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;

    if (widget.bookings.isEmpty) {
      return AvaFormShell(
        title: l.t('ava_mb_title'),
        children: [
          Text(
            l.t('ava_no_bookings'),
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
          ),
        ],
      );
    }

    return AvaFormShell(
      title: l.t('ava_mb_title'),
      children: [
        AvaSectionLabel(text: l.t('ava_mb_select')),
        const SizedBox(height: 10),
        // Bounded so a long list scrolls inside the bubble instead of
        // pushing the Save button off the conversation.
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 236),
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (final b in widget.bookings)
                  AvaBookingOption(
                    booking: b,
                    selected: _selectedId == AvaBookingOption.idOf(b),
                    onTap: _submitted
                        ? () {}
                        : () => setState(
                            () => _selectedId = AvaBookingOption.idOf(b)),
                  ),
              ],
            ),
          ),
        ),
        if (_selectedId != null) ...[
          const SizedBox(height: 12),
          AvaSectionLabel(text: l.t('ava_mb_what')),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AvaChoiceChip(
                label: l.t('ava_bf_date'),
                selected: _active.contains(_Field.date),
                enabled: !_submitted,
                onTap: () => _toggle(_Field.date),
              ),
              AvaChoiceChip(
                label: l.t('ava_bf_time'),
                selected: _active.contains(_Field.time),
                enabled: !_submitted,
                onTap: () => _toggle(_Field.time),
              ),
              AvaChoiceChip(
                label: l.t('ava_bf_passengers'),
                selected: _active.contains(_Field.passengers),
                enabled: !_submitted,
                onTap: () => _toggle(_Field.passengers),
              ),
            ],
          ),
          if (_active.contains(_Field.date)) ...[
            const SizedBox(height: 14),
            AvaPickerRow(
              icon: Icons.calendar_today_rounded,
              label: l.t('ava_mb_new_date'),
              value: _date == null
                  ? null
                  : DateFormat('d MMM yyyy').format(_date!),
              placeholder: l.t('ava_bf_select'),
              enabled: !_submitted,
              onTap: _pickDate,
            ),
          ],
          if (_active.contains(_Field.time)) ...[
            const SizedBox(height: 10),
            AvaPickerRow(
              icon: Icons.schedule_rounded,
              label: l.t('ava_mb_new_time'),
              value: _time == null
                  ? null
                  : '${_time!.hour.toString().padLeft(2, '0')}:'
                      '${_time!.minute.toString().padLeft(2, '0')}',
              placeholder: l.t('ava_bf_select'),
              enabled: !_submitted,
              onTap: _pickTime,
            ),
          ],
          if (_active.contains(_Field.passengers)) ...[
            const SizedBox(height: 10),
            AvaCounterRow(
              icon: Icons.people_alt_rounded,
              label: l.t('ava_bf_passengers'),
              value: _passengers,
              min: 1,
              max: 12,
              enabled: !_submitted,
              onChanged: (v) => setState(() => _passengers = v),
            ),
          ],
        ],
        const SizedBox(height: 18),
        AvaPrimaryButton(
          label: _submitted ? l.t('ava_bf_sent') : l.t('ava_mb_save'),
          icon: _submitted ? Icons.check_rounded : Icons.save_outlined,
          enabled: _canSave,
          onTap: _submit,
        ),
      ],
    );
  }
}
