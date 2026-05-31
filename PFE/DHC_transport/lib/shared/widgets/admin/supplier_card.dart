import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/supplier_model.dart';
import 'admin_card.dart';

class SupplierCard extends StatelessWidget {
  final SupplierModel supplier;
  final VoidCallback onEdit;
  final VoidCallback onSuspend;
  final VoidCallback onReactivate;

  const SupplierCard({
    super.key,
    required this.supplier,
    required this.onEdit,
    required this.onSuspend,
    required this.onReactivate,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = supplier.status.label.toLowerCase().contains('active');
    final statusColor =
        isActive ? const Color(0xFF4DAA6B) : const Color(0xFFB07C24);
    final statusBackground = statusColor.withValues(alpha: 0.12);

    return AdminCard(
      label: supplier.name,
      value: supplier.status.label,
      subtitle: supplier.email,
      icon: supplier.icon,
      accentColor: AppColors.secondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoRow(label: 'Phone', value: supplier.phone),
          const SizedBox(height: 8),
          _InfoRow(label: 'Email', value: supplier.email),
          const SizedBox(height: 8),
          _InfoRow(label: 'Handle', value: supplier.handle),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: statusBackground,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: statusColor.withValues(alpha: 0.15)),
              ),
              child: Text(
                supplier.status.label,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: 'Edit',
                  icon: Icons.edit_outlined,
                  onTap: onEdit,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  label: isActive ? 'Suspend' : 'Reactivate',
                  icon: isActive
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline,
                  onTap: isActive ? onSuspend : onReactivate,
                  danger: isActive,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              color: Color(0xFF7B7D7D),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final background =
        danger ? const Color(0x33200000) : AppColors.surfaceElevated;
    final foreground = danger ? const Color(0xFFB85B4E) : AppColors.textPrimary;
    final border = danger ? const Color(0x66B85B4E) : AppColors.border;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: foreground),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
