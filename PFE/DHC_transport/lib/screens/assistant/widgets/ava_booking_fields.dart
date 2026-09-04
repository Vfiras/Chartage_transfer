import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/language_service.dart';

/// Shared pieces for AVA's interactive booking / modify / cancel cards.
///
/// The three cards look like one family because they are built from these, and
/// each one submits by handing the chat a single complete sentence — the
/// transport stays the ordinary text message flow, so nothing on the backend
/// had to learn a new event type.

/// Vehicle classes offered in the booking card.
const kAvaVehicleTypes = <String>[
  'Economy',
  'Comfort',
  'Business',
  'First Class',
  'VIP',
  'Van',
  'Minibus',
];

/// A completed booking form, and the sentence it turns into.
class AvaBookingFields {
  final String pickup;
  final String destination;
  final DateTime date;
  final TimeOfDay time;
  final int passengers;
  final int luggage;
  final String vehicle;

  const AvaBookingFields({
    required this.pickup,
    required this.destination,
    required this.date,
    required this.time,
    required this.passengers,
    required this.luggage,
    required this.vehicle,
  });

  /// One sentence carrying every field, so AVA has nothing left to ask.
  ///
  /// The date is ISO and the time 24h because those are the formats the
  /// booking tool parses; a localised "2 sept." would not round-trip.
  String toRequestSentence() {
    final d = DateFormat('yyyy-MM-dd').format(date);
    final t = '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
    return 'Please book a one-way trip from $pickup to $destination '
        'on $d at $t for $passengers passengers, $luggage bags, '
        'vehicle type $vehicle. Confirm and proceed.';
  }
}

// ─── Card shell ──────────────────────────────────────────────────────────────

/// Gold-topped card matching the other AVA cards in the chat.
class AvaFormShell extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const AvaFormShell({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18, right: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: AppColors.secondary.withValues(alpha: 0.22)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(height: 3, color: AppColors.secondary),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 13, 14, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: TextStyle(
                        color: AppColors.secondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ...children,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AvaSectionLabel extends StatelessWidget {
  final String text;
  const AvaSectionLabel({super.key, required this.text});

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: TextStyle(
          color: AppColors.secondary,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
        ),
      );
}

// ─── Picker row (date / time) ────────────────────────────────────────────────

class AvaPickerRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final String placeholder;
  final bool enabled;
  final VoidCallback onTap;

  const AvaPickerRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final filled = value != null;
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.textMuted),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
          ),
        ),
        GestureDetector(
          onTap: enabled ? onTap : null,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: filled
                    ? AppColors.secondary.withValues(alpha: 0.55)
                    : AppColors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  filled ? value! : placeholder,
                  style: TextStyle(
                    color: filled
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                    fontSize: 13,
                    fontWeight: filled ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.expand_more_rounded,
                    size: 16, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Counter row (passengers / luggage) ──────────────────────────────────────

class AvaCounterRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final int min;
  final int max;
  final bool enabled;
  final ValueChanged<int> onChanged;

  const AvaCounterRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.textMuted),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
          ),
        ),
        _StepButton(
          icon: Icons.remove_rounded,
          enabled: enabled && value > min,
          onTap: () => onChanged(value - 1),
        ),
        SizedBox(
          width: 34,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        _StepButton(
          icon: Icons.add_rounded,
          enabled: enabled && value < max,
          onTap: () => onChanged(value + 1),
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _StepButton(
      {required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(
            color: enabled ? AppColors.border : AppColors.border,
          ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: enabled ? AppColors.secondary : AppColors.textMuted,
        ),
      ),
    );
  }
}

// ─── Choice chip ─────────────────────────────────────────────────────────────

class AvaChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const AvaChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.secondary : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? AppColors.secondary
                : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            // Gold fill needs dark text; the palette's textPrimary is light
            // in dark mode and would vanish on the selected chip.
            color: selected
                ? const Color(0xFF141313)
                : AppColors.textSecondary,
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ─── Primary / danger buttons ────────────────────────────────────────────────

class AvaPrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool enabled;
  final VoidCallback onTap;
  final bool danger;

  const AvaPrimaryButton({
    super.key,
    required this.label,
    this.icon,
    required this.enabled,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final fill = danger ? AppColors.danger : AppColors.secondary;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? fill : fill.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(12),
        ),
        // Side-by-side buttons only get half the card each, and the labels
        // are longer in French — let the text shrink rather than overflow.
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon,
                    size: 17,
                    color: enabled
                        ? (danger ? Colors.white : const Color(0xFF141313))
                        : AppColors.textMuted),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: enabled
                        ? (danger ? Colors.white : const Color(0xFF141313))
                        : AppColors.textMuted,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AvaSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const AvaSecondaryButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ─── Selectable booking row (modify / cancel) ────────────────────────────────

/// One upcoming booking, rendered compactly and radio-selectable.
class AvaBookingOption extends StatelessWidget {
  final Map<String, dynamic> booking;
  final bool selected;
  final VoidCallback onTap;

  const AvaBookingOption({
    super.key,
    required this.booking,
    required this.selected,
    required this.onTap,
  });

  static String routeOf(Map<String, dynamic> b) {
    final from = (b['pickup_location'] ?? '?').toString();
    final to = (b['destination_name'] ?? b['destination_city'] ?? '?').toString();
    return '${_short(from)} → ${_short(to)}';
  }

  static String _short(String s) =>
      s.length <= 22 ? s : '${s.substring(0, 21)}…';

  static String idOf(Map<String, dynamic> b) =>
      (b['_id'] ?? b['id'] ?? '').toString();

  @override
  Widget build(BuildContext context) {
    final status = (booking['status'] ?? '').toString();
    final date = (booking['departure_date'] ?? '').toString();
    final time = (booking['departure_time'] ?? '').toString();

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.secondary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 18,
              color: selected ? AppColors.secondary : AppColors.textMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    routeOf(booking),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [date, if (time.isNotEmpty) time].join(' · '),
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            if (status.isNotEmpty) _StatusPill(status: status),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;
    final (colour, key) = switch (status) {
      'pending' => (const Color(0xFFF59E0B), 'admin_st_pending'),
      'confirmed' => (const Color(0xFF10B981), 'admin_st_confirmed'),
      'on_route' => (const Color(0xFF3B82F6), 'admin_st_on_route'),
      'completed' => (const Color(0xFF14B8A6), 'admin_st_completed'),
      'cancelled' => (const Color(0xFFE07A7A), 'admin_st_cancelled'),
      _ => (AppColors.textMuted, ''),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        key.isEmpty ? status : l.t(key),
        style: TextStyle(
          color: colour,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
