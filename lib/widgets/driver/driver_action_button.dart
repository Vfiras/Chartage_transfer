import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

enum DriverActionButtonVariant { gold, dark, light, success, danger }

class DriverActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final DriverActionButtonVariant variant;
  final bool expanded;
  final double height;

  const DriverActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = DriverActionButtonVariant.gold,
    this.expanded = true,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;

    final background = switch (variant) {
      DriverActionButtonVariant.gold => disabled
          ? const Color(0xFF3B3320)
          : AppColors.secondary,
      DriverActionButtonVariant.dark => const Color(0xFF1B1B1B),
      DriverActionButtonVariant.light => const Color(0xFFF4F1E7),
      DriverActionButtonVariant.success => const Color(0xFF183523),
      DriverActionButtonVariant.danger => const Color(0xFF351B1B),
    };

    final foreground = switch (variant) {
      DriverActionButtonVariant.gold => AppColors.primary,
      DriverActionButtonVariant.dark => Colors.white,
      DriverActionButtonVariant.light => AppColors.primary,
      DriverActionButtonVariant.success => const Color(0xFF66E08D),
      DriverActionButtonVariant.danger => const Color(0xFFFF8D8D),
    };

    final borderColor = switch (variant) {
      DriverActionButtonVariant.gold => Colors.transparent,
      DriverActionButtonVariant.dark => const Color(0x26FFFFFF),
      DriverActionButtonVariant.light => Colors.transparent,
      DriverActionButtonVariant.success => const Color(0x264CD97B),
      DriverActionButtonVariant.danger => const Color(0x264B4B4B),
    };

    return SizedBox(
      width: expanded ? double.infinity : null,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
          boxShadow: variant == DriverActionButtonVariant.gold && !disabled
              ? const [
                  BoxShadow(
                    color: Color(0x55E6A200),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ]
              : const [],
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: foreground,
            disabledForegroundColor: foreground.withValues(alpha: 0.55),
            disabledBackgroundColor: Colors.transparent,
            elevation: 0,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
