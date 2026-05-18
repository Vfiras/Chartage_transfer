import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';

const _gold = Color(0xFFF0B33A);
const _goldDark = Color(0xFFD89624);
const _fieldFill = Color(0xFF111215);
const _fieldBorder = Color(0xFF24272C);
const _panelBorder = Color(0xFF2A2D31);

class AuthScaffold extends StatelessWidget {
  final Widget child;
  final bool showImage;
  final Alignment imageAlignment;

  const AuthScaffold({
    super.key,
    required this.child,
    this.showImage = true,
    this.imageAlignment = Alignment.bottomCenter,
  });

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.background,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (showImage)
              Image.asset(
                'assets/images/Gemini_Generated_Image_e8gc14e8gc14e8gc.png',
                fit: BoxFit.cover,
                alignment: imageAlignment,
                filterQuality: FilterQuality.high,
              ),
            if (!showImage) const ColoredBox(color: Color(0xFF050608)),
            SafeArea(child: child),
          ],
        ),
      ),
    );
  }
}

class AuthBrandLockup extends StatelessWidget {
  final bool compact;
  final bool stacked;

  const AuthBrandLockup(
      {super.key, this.compact = false, this.stacked = false});

  @override
  Widget build(BuildContext context) {
    if (stacked) {
      return Column(
        children: [
          Image.asset(
            'assets/images/logo fav.png',
            width: compact ? 86 : 118,
            height: compact ? 86 : 118,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
          SizedBox(height: compact ? 14 : 20),
          Image.asset(
            'assets/images/logo.png',
            width: compact ? 210 : 292,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ],
      );
    }

    return Column(
      children: [
        Container(
          width: compact ? 72 : 112,
          height: compact ? 72 : 112,
          padding: EdgeInsets.all(compact ? 2 : 0),
          child: Image.asset(
            'assets/images/logo fav.png',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
        SizedBox(height: compact ? 12 : 18),
        Image.asset(
          'assets/images/logo.png',
          width: compact ? 230 : 315,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ],
    );
  }
}

class AuthPageFrame extends StatelessWidget {
  final Widget child;
  final bool showImage;
  final Alignment imageAlignment;
  final Alignment contentAlignment;

  const AuthPageFrame({
    super.key,
    required this.child,
    this.showImage = true,
    this.imageAlignment = Alignment.bottomCenter,
    this.contentAlignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showImage: showImage,
      imageAlignment: imageAlignment,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 24),
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(minHeight: constraints.maxHeight - 34),
              child: Align(
                alignment: contentAlignment,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: child,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class AuthBackButton extends StatelessWidget {
  const AuthBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: IconButton(
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 44, height: 44),
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: AppColors.textPrimary,
          size: 22,
        ),
      ),
    );
  }
}

class AuthTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const AuthTitle({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.montserrat(
            color: AppColors.textPrimary,
            fontSize: 23,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final Widget? suffixIcon;
  final VoidCallback? onSuffixTap;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final String? Function(String?)? validator;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.obscureText = false,
    this.suffixIcon,
    this.onSuffixTap,
    this.keyboardType,
    this.autofillHints,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        autofillHints: autofillHints,
        validator: validator,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(
            color: Color(0xFF85878D),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          errorStyle: const TextStyle(height: 0.01, fontSize: 0),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          filled: true,
          fillColor: _fieldFill.withValues(alpha: 0.9),
          suffixIcon: suffixIcon == null
              ? null
              : InkWell(onTap: onSuffixTap, child: suffixIcon),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _fieldBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _fieldBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.goldBorder),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.danger),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.danger),
          ),
        ),
      ),
    );
  }
}

class AuthPrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool loading;

  const AuthPrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF6C04C), _goldDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: FilledButton(
          onPressed: loading ? null : onPressed,
          style: FilledButton.styleFrom(
            elevation: 0,
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: AppColors.primary,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                )
              : Text(
                  text,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
      ),
    );
  }
}

class AuthOutlineButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color borderColor;
  final Color backgroundColor;

  const AuthOutlineButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.borderColor = AppColors.goldBorder,
    this.backgroundColor = Colors.transparent,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: AppColors.textPrimary,
          side: BorderSide(color: borderColor),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class AuthDividerLabel extends StatelessWidget {
  final String text;

  const AuthDividerLabel({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: _panelBorder, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Expanded(child: Divider(color: _panelBorder, height: 1)),
      ],
    );
  }
}

class AuthSocialButtons extends StatelessWidget {
  final VoidCallback onGoogle;

  const AuthSocialButtons({
    super.key,
    required this.onGoogle,
  });

  @override
  Widget build(BuildContext context) {
    return _SocialButton(
      onPressed: onGoogle,
      child: const GoogleLogoMark(size: 24),
    );
  }
}

class GoogleLogoMark extends StatelessWidget {
  final double size;

  const GoogleLogoMark({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.15;
    final rect = Offset(stroke / 2, stroke / 2) &
        Size(size.width - stroke, size.height - stroke);

    void arc(Color color, double start, double sweep) {
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.square,
      );
    }

    arc(const Color(0xFF4285F4), -0.08, 1.48);
    arc(const Color(0xFF34A853), 1.25, 1.15);
    arc(const Color(0xFFFBBC05), 2.25, 1.22);
    arc(const Color(0xFFEA4335), 3.28, 1.35);

    final blue = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(
      Offset(size.width * 0.54, size.height * 0.50),
      Offset(size.width * 0.92, size.height * 0.50),
      blue,
    );
    canvas.drawLine(
      Offset(size.width * 0.92, size.height * 0.50),
      Offset(size.width * 0.78, size.height * 0.68),
      blue,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SocialButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onPressed;

  const _SocialButton({required this.child, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.transparent,
          side: const BorderSide(color: _panelBorder),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: child,
      ),
    );
  }
}

class AuthBottomPrompt extends StatelessWidget {
  final String text;
  final String action;
  final VoidCallback onPressed;

  const AuthBottomPrompt({
    super.key,
    required this.text,
    required this.action,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          text,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            action,
            style: const TextStyle(
              color: _gold,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class AuthBodyCard extends StatelessWidget {
  final Widget child;

  const AuthBodyCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0x33000000),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
      ),
      child: child,
    );
  }
}
