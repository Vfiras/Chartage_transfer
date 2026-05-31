import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class NotificationSection extends StatelessWidget {
  final String label;
  final bool isToday;

  const NotificationSection({
    super.key,
    required this.label,
    this.isToday = false,
  });

  @override
  Widget build(BuildContext context) {
    final gold = AppColors.secondary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: isToday ? gold : AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.5,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 1,
              color: gold.withValues(alpha: isToday ? 0.18 : 0.10),
            ),
          ),
        ],
      ),
    );
  }
}
