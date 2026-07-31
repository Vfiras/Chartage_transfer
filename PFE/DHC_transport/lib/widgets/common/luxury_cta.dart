import 'package:flutter/material.dart';

/// The ONE primary call-to-action spec for the whole app.
///
/// Luxury brands never surprise you with an unexpected button: every primary
/// CTA is 52px tall, radius 14, gold fill, Montserrat w800 at 15px on dark
/// ink. The outlined variant is the matching secondary action.
const _gold = Color(0xFFC8A96B);
const _ink = Color(0xFF221A08);

class LuxuryCta extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool loading;

  /// Secondary style: transparent fill, subtle outline, muted label.
  final bool outlined;

  const LuxuryCta({
    super.key,
    required this.text,
    required this.onTap,
    this.icon,
    this.loading = false,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !loading;
    final labelColor = outlined
        ? Colors.white.withValues(alpha: 0.72)
        : _ink;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: outlined ? Colors.transparent : _gold,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: outlined
                  ? Border.all(color: Colors.white.withValues(alpha: 0.16))
                  : null,
            ),
            child: loading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: outlined ? _gold : _ink,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: labelColor, size: 19),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        text,
                        style: TextStyle(
                          color: labelColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
