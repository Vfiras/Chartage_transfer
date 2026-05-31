import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../widgets/common/fallback_network_image.dart';

enum LuxuryButtonVariant { primary, outline, ghost }

class LuxuryBackdrop extends StatelessWidget {
  final Widget child;

  const LuxuryBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    AppColors.setDarkMode(Theme.of(context).brightness == Brightness.dark);

    final colors = AppColors.isDark
        ? [
            AppColors.background,
            const Color(0xFF050403),
            const Color(0xFF000000),
          ]
        : [
            AppColors.background,
            const Color(0xFFFFFEFA),
            const Color(0xFFF1E8D7),
          ];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
          stops: [0, 0.62, 1],
        ),
      ),
      child: child,
    );
  }
}

class LuxuryScaffold extends StatelessWidget {
  final Widget body;
  final String? title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;
  final Widget? bottomNavigationBar;
  final EdgeInsetsGeometry padding;
  final bool scrollable;

  const LuxuryScaffold({
    super.key,
    required this.body,
    this.title,
    this.subtitle,
    this.leading,
    this.actions = const [],
    this.bottomNavigationBar,
    this.padding = const EdgeInsets.fromLTRB(18, 14, 18, 24),
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null || leading != null || actions.isNotEmpty) ...[
            LuxuryHeader(
              title: title ?? '',
              subtitle: subtitle,
              leading: leading,
              actions: actions,
            ),
            const SizedBox(height: 18),
          ],
          if (scrollable) body else Expanded(child: body),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: bottomNavigationBar,
      body: LuxuryBackdrop(
        child: SafeArea(
          child: scrollable ? ListView(children: [content]) : content,
        ),
      ),
    );
  }
}

class LuxuryHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;

  const LuxuryHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 10)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (subtitle != null) ...[
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
              ],
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
            ],
          ),
        ),
        ...actions,
      ],
    );
  }
}

class LuxuryCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final bool selected;
  final VoidCallback? onTap;
  final double radius;
  final Color? color;

  const LuxuryCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.selected = false,
    this.onTap,
    this.radius = 18,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    AppColors.setDarkMode(dark);
    final shadowColor =
        dark ? const Color(0xCC000000) : const Color(0x143B2A10);
    final cardColor =
        color ?? (dark ? const Color(0xFF101010) : const Color(0xFFFFFEFA));

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(radius),
        border: dark || selected
            ? Border.all(
                color: selected ? AppColors.accent : AppColors.softBorder,
                width: selected ? 1.6 : 1,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
          if (selected)
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.24),
              blurRadius: 28,
              spreadRadius: 1,
            ),
        ],
      ),
      child: child,
    );

    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius),
      child: card,
    );
  }
}

class LuxuryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Widget? icon;
  final bool loading;
  final LuxuryButtonVariant variant;
  final double height;

  const LuxuryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.variant = LuxuryButtonVariant.primary,
    this.height = 54,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final primary = variant == LuxuryButtonVariant.primary;
    final outline = variant == LuxuryButtonVariant.outline;
    return InkWell(
      onTap: enabled ? onPressed : null,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: height,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: primary
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: enabled
                      ? const [AppColors.secondaryLight, AppColors.secondary]
                      : [
                          AppColors.secondary.withValues(alpha: 0.30),
                          AppColors.secondaryDark.withValues(alpha: 0.25),
                        ],
                )
              : null,
          color: primary ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: outline && AppColors.isDark
              ? Border.all(color: AppColors.goldBorder)
              : null,
          boxShadow: primary && enabled
              ? [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.25),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ]
              : const [],
        ),
        child: IconTheme(
          data: IconThemeData(
            color: primary ? AppColors.primary : AppColors.accentText,
          ),
          child: DefaultTextStyle(
            style: TextStyle(
              color: primary ? AppColors.primary : AppColors.accentText,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (loading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (icon != null)
                  icon!,
                if (loading || icon != null) const SizedBox(width: 8),
                Text(
                  text,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LuxuryTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hintText;
  final IconData icon;
  final bool obscureText;
  final Widget? suffixIcon;
  final VoidCallback? onSuffixTap;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final String? Function(String?)? validator;
  final int maxLines;

  const LuxuryTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hintText,
    required this.icon,
    this.obscureText = false,
    this.suffixIcon,
    this.onSuffixTap,
    this.keyboardType,
    this.autofillHints,
    this.validator,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          autofillHints: autofillHints,
          validator: validator,
          maxLines: maxLines,
          style: TextStyle(
              color: AppColors.textPrimary, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: Icon(icon, color: AppColors.secondary),
            suffixIcon: suffixIcon == null
                ? null
                : InkWell(
                    onTap: onSuffixTap,
                    child: suffixIcon,
                  ),
          ),
        ),
      ],
    );
  }
}

class LuxurySectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const LuxurySectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
            ],
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            child: Text(actionLabel!,
                style: TextStyle(color: AppColors.secondary)),
          ),
      ],
    );
  }
}

class LuxuryBottomNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const LuxuryBottomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class LuxuryBottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  final List<LuxuryBottomNavItem> items;
  final Set<int> badged;

  const LuxuryBottomNav({
    super.key,
    required this.index,
    required this.onChanged,
    required this.items,
    this.badged = const {},
  });

  @override
  Widget build(BuildContext context) {
    final navColor =
        AppColors.isDark ? const Color(0xF4000000) : const Color(0xFAFFFEFA);
    final shadowColor =
        AppColors.isDark ? const Color(0xCC000000) : const Color(0x224D3A16);

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        height: 66,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: navColor,
          borderRadius: BorderRadius.circular(22),
          border: AppColors.isDark ? Border.all(color: AppColors.border) : null,
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.08),
              blurRadius: 16,
            ),
          ],
        ),
        child: Row(
          children: List.generate(items.length, (i) {
            final item = items[i];
            final active = i == index;
            return Expanded(
              child: InkWell(
                onTap: () => onChanged(i),
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.accent.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: active && AppColors.isDark
                        ? Border.all(
                            color: AppColors.accent.withValues(alpha: 0.20),
                          )
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            active ? item.activeIcon : item.icon,
                            color: active
                                ? AppColors.accentText
                                : AppColors.textMuted,
                            size: 21,
                          ),
                          if (badged.contains(i))
                            Positioned(
                              top: -2,
                              right: -3,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Color(0xFFEF4444),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: active
                              ? AppColors.accentText
                              : AppColors.textMuted,
                          fontSize: 10.5,
                          fontWeight:
                              active ? FontWeight.w900 : FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class VehicleSelectionCard extends StatelessWidget {
  final String image;
  final String name;
  final String subtitle;
  final int seats;
  final int bags;
  final double price;
  final bool selected;
  final VoidCallback onTap;

  const VehicleSelectionCard({
    super.key,
    required this.image,
    required this.name,
    required this.subtitle,
    required this.seats,
    required this.bags,
    required this.price,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LuxuryCard(
      selected: selected,
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: FallbackNetworkImage(
                url: image, width: 104, height: 72, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.event_seat_rounded,
                        size: 14, color: AppColors.secondary),
                    const SizedBox(width: 4),
                    Text('$seats seats',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                    const SizedBox(width: 10),
                    Icon(Icons.luggage_rounded,
                        size: 14, color: AppColors.secondary),
                    const SizedBox(width: 4),
                    Text('$bags bags',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${price.toStringAsFixed(0)} TND',
                  style: TextStyle(
                      color: AppColors.secondary, fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? AppColors.secondary : AppColors.textMuted,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class BookingInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const BookingInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LuxuryStatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const LuxuryStatusChip({
    super.key,
    required this.label,
    this.color = AppColors.secondary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900),
      ),
    );
  }
}
