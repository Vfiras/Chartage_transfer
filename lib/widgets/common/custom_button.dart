import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

enum CustomButtonVariant { primary, secondary, outline, ghost }

class CustomButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final CustomButtonVariant variant;
  final bool expanded;
  final double height;

  const CustomButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = CustomButtonVariant.primary,
    this.expanded = true,
    this.height = 48,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    final background = switch (variant) {
      CustomButtonVariant.primary => disabled
          ? const Color(0xFFF2F2F2)
          : AppColors.secondary,
      CustomButtonVariant.secondary => disabled
          ? const Color(0xFFF2F2F2)
          : AppColors.surface,
      CustomButtonVariant.outline => Colors.transparent,
      CustomButtonVariant.ghost => Colors.transparent,
    };

    final borderColor = switch (variant) {
      CustomButtonVariant.primary => Colors.transparent,
      CustomButtonVariant.secondary => AppColors.border,
      CustomButtonVariant.outline => AppColors.border,
      CustomButtonVariant.ghost => Colors.transparent,
    };

    final foreground = switch (variant) {
      CustomButtonVariant.primary => AppColors.primary,
      CustomButtonVariant.secondary => AppColors.primary,
      CustomButtonVariant.outline => AppColors.primary,
      CustomButtonVariant.ghost => AppColors.textSecondary,
    };

    final shadow = variant == CustomButtonVariant.primary && !disabled
        ? const [
            BoxShadow(
              color: Color(0x33FFC107),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ]
        : const <BoxShadow>[];

    final button = SizedBox(
      width: expanded ? double.infinity : null,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
          boxShadow: shadow,
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: foreground,
            disabledBackgroundColor: Colors.transparent,
            disabledForegroundColor: AppColors.textHint,
            elevation: 0,
            minimumSize: Size.zero,
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
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
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.button.copyWith(color: foreground),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (variant == CustomButtonVariant.ghost) {
      return SizedBox(
        width: expanded ? double.infinity : null,
        height: height,
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: foreground,
            backgroundColor: Colors.transparent,
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
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
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.button.copyWith(color: foreground),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return button;
  }
}
