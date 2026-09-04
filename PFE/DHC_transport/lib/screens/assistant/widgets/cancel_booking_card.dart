import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/language_service.dart';
import 'ava_booking_fields.dart';

/// Pick a booking and cancel it, in one card.
///
/// The destructive action stays behind an explicit selection plus a warning —
/// tapping the red button is the confirmation, so there is no second yes/no
/// round-trip to sit through.
class CancelBookingCard extends StatefulWidget {
  final List<Map<String, dynamic>> bookings;
  final void Function(String formattedMessage) onSubmit;

  /// Dismisses the card without cancelling anything.
  final VoidCallback? onDismiss;

  const CancelBookingCard({
    super.key,
    required this.bookings,
    required this.onSubmit,
    this.onDismiss,
  });

  @override
  State<CancelBookingCard> createState() => _CancelBookingCardState();
}

class _CancelBookingCardState extends State<CancelBookingCard> {
  String? _selectedId;
  bool _submitted = false;
  bool _dismissed = false;

  void _submit() {
    if (_selectedId == null || _submitted) return;
    setState(() => _submitted = true);
    widget.onSubmit('Cancel booking $_selectedId. Yes I confirm.');
  }

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;

    if (_dismissed) {
      return AvaFormShell(
        title: l.t('ava_cb_title'),
        children: [
          Text(
            l.t('ava_cb_dismissed'),
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
          ),
        ],
      );
    }

    if (widget.bookings.isEmpty) {
      return AvaFormShell(
        title: l.t('ava_cb_title'),
        children: [
          Text(
            l.t('ava_no_bookings'),
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
          ),
        ],
      );
    }

    return AvaFormShell(
      title: l.t('ava_cb_title'),
      children: [
        AvaSectionLabel(text: l.t('ava_cb_select')),
        const SizedBox(height: 10),
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
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: AppColors.danger.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(9),
            border:
                Border.all(color: AppColors.danger.withValues(alpha: 0.30)),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  size: 16, color: AppColors.danger),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  l.t('ava_cb_warning'),
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: AvaPrimaryButton(
                label: _submitted
                    ? l.t('ava_bf_sent')
                    : l.t('ava_cb_confirm'),
                // No icon while idle: side-by-side buttons are narrow and the
                // red fill already reads as destructive.
                icon: _submitted ? Icons.check_rounded : null,
                enabled: _selectedId != null && !_submitted,
                danger: true,
                onTap: _submit,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AvaSecondaryButton(
                label: l.t('ava_cb_back'),
                onTap: () {
                  setState(() => _dismissed = true);
                  widget.onDismiss?.call();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
