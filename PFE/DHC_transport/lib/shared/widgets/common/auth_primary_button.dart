import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';

class AuthPrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Widget? trailing;
  final double height;

  const AuthPrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.trailing,
    this.height = 58,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;

    return SizedBox(
      width: double.infinity,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: disabled
              ? null
              : LinearGradient(
                  colors: [
                    Color(0xFFEEC96B),
                    Color(0xFFE4B756),
                    Color(0xFFD8A93C)
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
          color: disabled ? const Color(0xFFF1F1F1) : null,
          boxShadow: disabled
              ? null
              : const [
                  BoxShadow(
                    color: Color(0x33E4B756),
                    blurRadius: 22,
                    offset: Offset(0, 10),
                  ),
                ],
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                style: GoogleFonts.comfortaa(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: disabled ? AppColors.textMuted : AppColors.primary,
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 10),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
