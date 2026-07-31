import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/models/user_model.dart';
import '../../../widgets/common/fallback_network_image.dart';

class PremiumProfilePalette {
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color background(BuildContext context) =>
      isDark(context) ? const Color(0xFF0B0B0D) : const Color(0xFFF8F2E8);

  static Color surface(BuildContext context) =>
      isDark(context) ? const Color(0xFF141416) : const Color(0xFFFFFCF7);

  static Color elevated(BuildContext context) =>
      isDark(context) ? const Color(0xFF1C1C1F) : const Color(0xFFFBF1E7);

  static Color border(BuildContext context) =>
      isDark(context) ? const Color(0x14FFFFFF) : const Color(0xFFEADCCB);

  static Color text(BuildContext context) =>
      isDark(context) ? Colors.white : const Color(0xFF17130E);

  static Color subtitle(BuildContext context) =>
      isDark(context) ? const Color(0xFFA1A1AA) : const Color(0xFF7D746A);

  static const Color gold = Color(0xFFC8A96B);
  static const Color goldDeep = Color(0xFF402D00);
}

class PremiumProfileBackground extends StatelessWidget {
  final Widget child;

  const PremiumProfileBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final dark = PremiumProfilePalette.isDark(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? const [
                  Color(0xFF0B0B0D),
                  Color(0xFF0B0B0D),
                  Color(0xFF09090B),
                ]
              : const [
                  Color(0xFFF8F2E8),
                  Color(0xFFF5EEE3),
                  Color(0xFFF2E8D9),
                ],
        ),
      ),
      child: child,
    );
  }
}

class PremiumProfileTopBar extends StatelessWidget {
  final String title;
  final VoidCallback? onLeadingTap;
  final Widget trailing;
  final bool showMenu;

  const PremiumProfileTopBar({
    super.key,
    required this.title,
    required this.trailing,
    this.onLeadingTap,
    this.showMenu = true,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = PremiumProfilePalette.gold;
    return Row(
      children: [
        GestureDetector(
          onTap: onLeadingTap,
          child: Icon(
            showMenu ? Icons.menu_rounded : Icons.arrow_back_rounded,
            color: textColor,
            size: 26,
          ),
        ),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ),
        trailing,
      ],
    );
  }
}

class PremiumProfileAvatar extends StatelessWidget {
  final UserModel user;
  final double size;
  final VoidCallback? onEditTap;
  final bool showEditBadge;

  const PremiumProfileAvatar({
    super.key,
    required this.user,
    this.size = 132,
    this.onEditTap,
    this.showEditBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    final dark = PremiumProfilePalette.isDark(context);
    return SizedBox(
      width: size + 18,
      height: size + 18,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Center(
            child: Container(
              width: size,
              height: size,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    PremiumProfilePalette.gold.withValues(alpha: 0.58),
                    PremiumProfilePalette.gold.withValues(alpha: 0.16),
                    PremiumProfilePalette.gold.withValues(alpha: 0.48),
                  ],
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: PremiumProfilePalette.surface(context),
                  border: Border.all(
                    color: dark ? const Color(0xFF0B0B0D) : Colors.white,
                    width: 3,
                  ),
                ),
                child: ClipOval(
                  child: user.avatarUrl == null || user.avatarUrl!.isEmpty
                      ? Container(
                          color: PremiumProfilePalette.elevated(context),
                          alignment: Alignment.center,
                          child: Text(
                            user.initials,
                            style: TextStyle(
                              color: PremiumProfilePalette.text(context),
                              fontSize: size * 0.25,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      : FallbackNetworkImage(
                          url: user.avatarUrl!, fit: BoxFit.cover),
                ),
              ),
            ),
          ),
          if (showEditBadge)
            Positioned(
              right: 0,
              bottom: 12,
              child: GestureDetector(
                onTap: onEditTap,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: PremiumProfilePalette.gold,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: dark ? const Color(0xFF0B0B0D) : Colors.white,
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.edit_outlined,
                    color: PremiumProfilePalette.goldDeep,
                    size: 20,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class PremiumProfilePrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;

  const PremiumProfilePrimaryButton({
    super.key,
    required this.text,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: PremiumProfilePalette.gold,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            color: PremiumProfilePalette.goldDeep,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}

class PremiumProfileActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const PremiumProfileActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: PremiumProfilePalette.surface(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: PremiumProfilePalette.border(context)),
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: PremiumProfilePalette.elevated(context),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: PremiumProfilePalette.gold, size: 28),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: PremiumProfilePalette.text(context),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: PremiumProfilePalette.subtitle(context),
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: PremiumProfilePalette.subtitle(context),
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}

class PremiumProfileTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final IconData icon;

  const PremiumProfileTextField({
    super.key,
    required this.label,
    required this.controller,
    required this.icon,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final dark = PremiumProfilePalette.isDark(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: PremiumProfilePalette.subtitle(context),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.2,
          ),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: PremiumProfilePalette.surface(context).withValues(
                  alpha: dark ? 0.92 : 0.98,
                ),
                borderRadius: BorderRadius.circular(22),
                border:
                    Border.all(color: PremiumProfilePalette.border(context)),
              ),
              child: TextFormField(
                controller: controller,
                keyboardType: keyboardType,
                validator: validator,
                style: TextStyle(
                  color: PremiumProfilePalette.text(context),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  prefixIcon: Icon(icon,
                      color: PremiumProfilePalette.gold, size: 22),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 20),
                  hintText: label,
                  hintStyle: TextStyle(
                    color: PremiumProfilePalette.subtitle(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class PremiumProfileGhostButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback? onTap;

  const PremiumProfileGhostButton({
    super.key,
    required this.text,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: Colors.transparent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFFF07777), size: 22),
            const SizedBox(width: 10),
            Text(
              text.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFFF07777),
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Badge under the profile name.
///
/// [loyaltyTier] comes from `GET /rewards/me`. Before the loyalty system was
/// real this returned a hardcoded "Black Tier" for every client, which now
/// contradicts the membership card directly below it — so the real tier is
/// used whenever it has loaded.
String premiumProfileRoleBadge(UserModel user, {String? loyaltyTier}) {
  if (user.isGuest) return 'Guest Access';
  if (user.role == 'admin') return 'Admin Access';
  final tier = loyaltyTier?.trim();
  if (tier != null && tier.isNotEmpty) return '$tier Tier';
  return 'Member';
}
