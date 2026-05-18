import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';

class CustomAuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final TextInputType keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final VoidCallback? onSuffixTap;
  final bool enabled;
  final Iterable<String>? autofillHints;
  final String? Function(String?)? validator;
  final int? maxLines;

  const CustomAuthTextField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.suffixIcon,
    this.onSuffixTap,
    this.enabled = true,
    this.autofillHints,
    this.validator,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    const fillColor = Color(0xFFF7F8FC);
    const borderColor = Color(0xFFE7E1D2);
    const iconColor = Color(0xFF8D8D8D);

    return TextFormField(
      controller: controller,
      enabled: enabled,
      obscureText: obscureText,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      validator: validator,
      maxLines: maxLines,
      style: GoogleFonts.comfortaa(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.comfortaa(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppColors.textMuted,
        ),
        filled: true,
        fillColor: fillColor,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        prefixIcon: Icon(prefixIcon, color: iconColor, size: 21),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 54, minHeight: 24),
        suffixIcon: suffixIcon == null
            ? null
            : IconButton(
                onPressed: onSuffixTap,
                icon: suffixIcon!,
                color: iconColor,
                splashRadius: 20,
              ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: AppColors.secondary.withValues(alpha: 0.92),
            width: 1.2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE57373)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE57373), width: 1.2),
        ),
      ),
    );
  }
}
