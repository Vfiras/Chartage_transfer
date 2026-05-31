import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../widgets/common/fallback_network_image.dart';

class PremiumClientPalette {
  static const background = Color(0xFF0B0B0D);
  static const surface = Color(0xFF141416);
  static const elevated = Color(0xFF1C1C1F);
  static const gold = Color(0xFFE5C484);
  static const goldDeep = Color(0xFFC8A96B);
  static const text = Color(0xFFE9E1DA);
  static const muted = Color(0xFFA1A1AA);
  static const border = Color(0x1AE9E1DA);
}

class PremiumClientTheme {
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color background(BuildContext context) => isDark(context)
      ? PremiumClientPalette.background
      : const Color(0xFFFAF7EF);

  static Color surface(BuildContext context) =>
      isDark(context) ? PremiumClientPalette.surface : const Color(0xFFFFFEFA);

  static Color elevated(BuildContext context) =>
      isDark(context) ? PremiumClientPalette.elevated : const Color(0xFFFBF1E8);

  static Color text(BuildContext context) =>
      isDark(context) ? PremiumClientPalette.text : const Color(0xFF15120D);

  static Color muted(BuildContext context) =>
      isDark(context) ? PremiumClientPalette.muted : const Color(0xFF7E766B);

  static Color border(BuildContext context) =>
      isDark(context) ? PremiumClientPalette.border : const Color(0xFFEDE1D4);

  static Color glass(BuildContext context) =>
      isDark(context) ? const Color(0xB31C1C1F) : const Color(0xEAFFFCF6);

  static Color glassBorder(BuildContext context) =>
      isDark(context) ? const Color(0x1AFFFFFF) : const Color(0xFFE8DDCD);
}

class PremiumGlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadiusGeometry borderRadius;
  final Color? color;
  final Color? borderColor;

  const PremiumGlassPanel({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.color,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: color ?? PremiumClientTheme.glass(context),
            borderRadius: borderRadius,
            border: Border.all(
              color: borderColor ?? PremiumClientTheme.glassBorder(context),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class PremiumNavItem {
  final String label;
  final IconData icon;
  final IconData? activeIcon;

  const PremiumNavItem({
    required this.label,
    required this.icon,
    this.activeIcon,
  });
}

class PremiumClientNav extends StatelessWidget {
  final int index;
  final ValueChanged<int>? onChanged;
  final Set<int> badged;
  final List<PremiumNavItem> items;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry innerPadding;

  const PremiumClientNav({
    super.key,
    required this.index,
    this.onChanged,
    this.badged = const {},
    this.items = defaultItems,
    this.margin = const EdgeInsets.fromLTRB(24, 0, 24, 24),
    this.innerPadding = const EdgeInsets.symmetric(horizontal: 10),
  });

  static const defaultItems = [
    PremiumNavItem(
      label: 'Home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
    ),
    PremiumNavItem(
      label: 'Trips',
      icon: Icons.auto_graph_outlined,
      activeIcon: Icons.auto_graph_rounded,
    ),
    PremiumNavItem(
      label: 'Saved',
      icon: Icons.bookmark_border_rounded,
      activeIcon: Icons.bookmark_rounded,
    ),
    PremiumNavItem(
      label: 'Alerts',
      icon: Icons.notifications_none_rounded,
      activeIcon: Icons.notifications_rounded,
    ),
    PremiumNavItem(
      label: 'Profile',
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final horizontalMargin = width < 420 ? 18.0 : 24.0;
    final navColor = isDark ? const Color(0xE61C1C1F) : const Color(0xF8FFFCF6);
    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.10) : const Color(0xFFE8DDCD);
    final shadowColor =
        isDark ? Colors.black.withValues(alpha: 0.50) : const Color(0x333B2A10);
    final compactColor = isDark
        ? PremiumClientPalette.text.withValues(alpha: 0.62)
        : const Color(0xFF756D62);
    final badgeBorderColor =
        isDark ? const Color(0xE61C1C1F) : const Color(0xF8FFFCF6);

    return SafeArea(
      top: false,
      minimum: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          horizontalMargin,
          0,
          horizontalMargin,
          18,
        ),
        child: SizedBox(
          height: 64,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: shadowColor,
                      blurRadius: isDark ? 34 : 28,
                      offset: Offset(0, isDark ? 18 : 14),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      height: 64,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: navColor,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: borderColor),
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          const preferredCompactWidth = 48.0;
                          final activeWidth = (constraints.maxWidth -
                                  preferredCompactWidth * (items.length - 1))
                              .clamp(96.0, 120.0)
                              .toDouble();
                          final compactWidth =
                              ((constraints.maxWidth - activeWidth) /
                                      (items.length - 1))
                                  .clamp(44.0, preferredCompactWidth)
                                  .toDouble();

                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              for (var i = 0; i < items.length; i++)
                                _PremiumNavButton(
                                  item: items[i],
                                  selected: i == index,
                                  badged: badged.contains(i),
                                  activeWidth: activeWidth,
                                  compactWidth: compactWidth,
                                  compactColor: compactColor,
                                  badgeBorderColor: badgeBorderColor,
                                  onTap: onChanged == null
                                      ? null
                                      : () => onChanged!(i),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumNavButton extends StatelessWidget {
  final PremiumNavItem item;
  final bool selected;
  final bool badged;
  final double activeWidth;
  final double compactWidth;
  final Color compactColor;
  final Color badgeBorderColor;
  final VoidCallback? onTap;

  const _PremiumNavButton({
    required this.item,
    required this.selected,
    required this.badged,
    required this.activeWidth,
    required this.compactWidth,
    required this.compactColor,
    required this.badgeBorderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const onGold = Color(0xFF402D00);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 1 : 0.96,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOutCubic,
          width: selected ? activeWidth : compactWidth,
          height: 48,
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: selected ? PremiumClientPalette.gold : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: PremiumClientPalette.gold.withValues(alpha: 0.24),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final iconLeft =
                      selected ? 16.0 : ((width - 22) / 2).clamp(0.0, width);
                  final labelWidth = (width - 54).clamp(0.0, 72.0).toDouble();

                  return Stack(
                    children: [
                      Positioned(
                        left: iconLeft,
                        top: 0,
                        bottom: 0,
                        child: Icon(
                          selected ? item.activeIcon ?? item.icon : item.icon,
                          color: selected ? onGold : compactColor,
                          size: 22,
                        ),
                      ),
                      Positioned(
                        left: 48,
                        top: 0,
                        bottom: 0,
                        child: ClipRect(
                          child: SizedBox(
                            width: labelWidth,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 260),
                                curve: Curves.easeOutCubic,
                                opacity: selected && labelWidth > 12 ? 1 : 0,
                                child: AnimatedSlide(
                                  duration: const Duration(milliseconds: 360),
                                  curve: Curves.easeOutCubic,
                                  offset: selected
                                      ? Offset.zero
                                      : const Offset(0.25, 0),
                                  child: Text(
                                    _displayLabel(item.label),
                                    maxLines: 1,
                                    overflow: TextOverflow.clip,
                                    style: const TextStyle(
                                      color: onGold,
                                      fontSize: 12,
                                      height: 1,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              if (badged && !selected)
                Positioned(
                  top: 11,
                  right: 10,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6A6A),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: badgeBorderColor,
                        width: 1.2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _displayLabel(String label) {
    if (label.isEmpty) return label;
    final lower = label.toLowerCase();
    return '${lower[0].toUpperCase()}${lower.substring(1)}';
  }
}


class PremiumAvatar extends StatelessWidget {
  final double size;

  const PremiumAvatar({super.key, this.size = 42});

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: PremiumClientPalette.gold.withValues(alpha: 0.45),
        ),
      ),
      padding: const EdgeInsets.all(1),
      child: ClipOval(
        child: user?.avatarUrl != null
            ? FallbackNetworkImage(url: user!.avatarUrl!, fit: BoxFit.cover)
            : Container(
                color: PremiumClientTheme.elevated(context),
                child: Icon(
                  Icons.person_rounded,
                  color: PremiumClientPalette.gold,
                  size: size * 0.52,
                ),
              ),
      ),
    );
  }
}

class PremiumIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const PremiumIconButton({
    super.key,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: PremiumGlassPanel(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(icon, color: PremiumClientPalette.gold, size: 22),
        ),
      ),
    );
  }
}

class PremiumPrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final bool loading;

  const PremiumPrimaryButton({
    super.key,
    required this.text,
    this.onTap,
    this.leadingIcon,
    this.trailingIcon,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !loading;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        opacity: enabled ? 1 : 0.58,
        duration: const Duration(milliseconds: 160),
        child: Container(
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: PremiumClientPalette.goldDeep,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: PremiumClientPalette.goldDeep.withValues(alpha: 0.32),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: loading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.primary,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (leadingIcon != null) ...[
                      Icon(leadingIcon, color: AppColors.primary, size: 20),
                      const SizedBox(width: 10),
                    ],
                    Text(
                      text,
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (trailingIcon != null) ...[
                      const SizedBox(width: 10),
                      Icon(trailingIcon, color: AppColors.primary, size: 20),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

class PremiumMapPreview extends StatelessWidget {
  final String pickup;
  final String destination;
  final double height;

  const PremiumMapPreview({
    super.key,
    required this.pickup,
    required this.destination,
    this.height = 574,
  });

  @override
  Widget build(BuildContext context) {
    final hasRoute = pickup.trim().isNotEmpty || destination.trim().isNotEmpty;
    final isDark = PremiumClientTheme.isDark(context);
    final backgroundColor = PremiumClientTheme.background(context);
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: backgroundColor),
          CustomPaint(
            painter: _PremiumMapPainter(
              hasRoute: hasRoute,
              isDark: isDark,
              backgroundColor: backgroundColor,
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [
                        PremiumClientPalette.background.withValues(alpha: 0.86),
                        Colors.transparent,
                        Colors.transparent,
                        PremiumClientPalette.background.withValues(alpha: 0.92),
                      ]
                    : [
                        backgroundColor.withValues(alpha: 0.70),
                        Colors.transparent,
                        Colors.transparent,
                        backgroundColor.withValues(alpha: 0.96),
                      ],
                stops: const [0, 0.2, 0.76, 1],
              ),
            ),
          ),
          Positioned(
            top: 104,
            left: 30,
            right: 30,
            child: PremiumGlassPanel(
              borderRadius: BorderRadius.circular(34),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
              child: Row(
                children: [
                  Icon(Icons.explore_rounded,
                      color: PremiumClientPalette.gold, size: 22),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      hasRoute
                          ? 'OPTIMIZED ROUTE\nCALCULATED'
                          : 'ROUTE PREVIEW\nREADY',
                      style: const TextStyle(
                        color: PremiumClientPalette.gold,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        height: 1.42,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 28,
            bottom: 34,
            child: PremiumIconButton(
              icon: Icons.my_location_rounded,
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumMapPainter extends CustomPainter {
  final bool hasRoute;
  final bool isDark;
  final Color backgroundColor;

  const _PremiumMapPainter({
    required this.hasRoute,
    required this.isDark,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final roadColor = isDark ? Colors.white : const Color(0xFF675E52);
    final routeColor =
        isDark ? PremiumClientPalette.goldDeep : const Color(0xFFC8A96B);
    final roadPaint = Paint()
      ..color = roadColor.withValues(alpha: isDark ? 0.13 : 0.18)
      ..strokeWidth = 2.1
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width * 0.52, size.height * 0.42);
    for (var i = 0; i < 11; i++) {
      final radius = 42.0 + i * 31.0;
      canvas.drawCircle(center, radius, roadPaint);
    }

    for (var i = -5; i <= 5; i++) {
      final angle = (i * 16 + 8) * 3.14159 / 180;
      final start = Offset(
        center.dx + 24 * mathCos(angle),
        center.dy + 24 * mathSin(angle),
      );
      final end = Offset(
        center.dx + size.height * mathCos(angle),
        center.dy + size.height * mathSin(angle),
      );
      canvas.drawLine(start, end, roadPaint);
    }

    final arterial = Paint()
      ..color = roadColor.withValues(alpha: isDark ? 0.18 : 0.24)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final arterialPath = Path()
      ..moveTo(-20, size.height * 0.64)
      ..quadraticBezierTo(
        size.width * 0.22,
        size.height * 0.54,
        size.width * 0.52,
        size.height * 0.56,
      )
      ..quadraticBezierTo(
        size.width * 0.76,
        size.height * 0.58,
        size.width + 28,
        size.height * 0.34,
      );
    canvas.drawPath(arterialPath, arterial);

    final routePaint = Paint()
      ..color = routeColor
      ..strokeWidth = 3.3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4);
    final routePath = Path()
      ..moveTo(size.width * 0.22, size.height * 0.61)
      ..cubicTo(
        size.width * 0.38,
        size.height * 0.55,
        size.width * 0.58,
        size.height * 0.68,
        size.width * 0.72,
        size.height * 0.43,
      )
      ..quadraticBezierTo(
        size.width * 0.82,
        size.height * 0.25,
        size.width * 0.96,
        size.height * 0.19,
      );
    canvas.drawPath(routePath, routePaint);

    _drawMarker(canvas, Offset(size.width * 0.22, size.height * 0.61), true);
    _drawMarker(canvas, Offset(size.width * 0.96, size.height * 0.19), false);
  }

  void _drawMarker(Canvas canvas, Offset point, bool filled) {
    canvas.drawCircle(
      point,
      filled ? 8 : 6,
      Paint()..color = backgroundColor,
    );
    canvas.drawCircle(
      point,
      filled ? 7 : 6,
      Paint()
        ..color = filled ? PremiumClientPalette.goldDeep : Colors.transparent
        ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      point,
      3,
      Paint()..color = PremiumClientPalette.gold,
    );
  }

  @override
  bool shouldRepaint(covariant _PremiumMapPainter oldDelegate) =>
      oldDelegate.hasRoute != hasRoute ||
      oldDelegate.isDark != isDark ||
      oldDelegate.backgroundColor != backgroundColor;
}

double mathSin(double radians) {
  return Offset.fromDirection(radians).dy;
}

double mathCos(double radians) {
  return Offset.fromDirection(radians).dx;
}
