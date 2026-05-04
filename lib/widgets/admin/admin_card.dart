import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class AdminCard extends StatelessWidget {
  final String? label;
  final String? value;
  final String? subtitle;
  final IconData? icon;
  final Color? accentColor;
  final Widget? child;
  final EdgeInsetsGeometry padding;
  final bool compact;
  final VoidCallback? onTap;

  const AdminCard({
    super.key,
    this.label,
    this.value,
    this.subtitle,
    this.icon,
    this.accentColor,
    this.child,
    this.padding = const EdgeInsets.all(18),
    this.compact = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFF171717),
        borderRadius: BorderRadius.circular(compact ? 24 : 28),
        border: Border.all(color: const Color(0x1FFFFFFF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x44000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: compact ? 36 : 42,
                  height: compact ? 36 : 42,
                  decoration: BoxDecoration(
                    color: (accentColor ?? AppColors.secondary).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(compact ? 12 : 14),
                  ),
                  child: Icon(
                    icon,
                    color: accentColor ?? AppColors.secondary,
                    size: compact ? 18 : 20,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (label != null) ...[
                      Text(
                        label!.toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFF8A8A8A),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    if (value != null) ...[
                      Text(
                        value!,
                        style: TextStyle(
                          color: accentColor ?? Colors.white,
                          fontSize: compact ? 20 : 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: Color(0xFF9A9A9A),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (child != null) ...[
            const SizedBox(height: 18),
            child!,
          ],
        ],
      ),
    );

    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(compact ? 24 : 28),
      child: card,
    );
  }
}
