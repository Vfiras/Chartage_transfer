import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/user_model.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/language_service.dart';
import '../../../core/services/theme_service.dart';
import '../../../screens/assistant/admin_assistant_screen.dart';
import '../../../widgets/common/fallback_network_image.dart';
import 'admin_pricing_screen.dart';
import 'admin_promotions_screen.dart';

class AdminProfileScreen extends StatelessWidget {
  const AdminProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    AppColors.setDarkMode(Theme.of(context).brightness == Brightness.dark);
    final l = LanguageService.instance;
    final user = AuthService.instance.currentUser ??
        const UserModel(
          name: 'Admin',
          email: 'admin',
          phone: 'admin',
          role: 'admin',
        );

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 130),
        children: [
          // ── Identity header ────────────────────────────────────────────
          Center(child: _AdminAvatar(user: user)),
          const SizedBox(height: 18),
          Text(
            user.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                    color: AppColors.secondary.withValues(alpha: 0.4)),
              ),
              child: Text(
                l.t('admin_role_badge'),
                style: TextStyle(
                  color: AppColors.secondary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            user.email,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 14),
          ),
          const SizedBox(height: 26),

          // ── Account info ───────────────────────────────────────────────
          _SectionTitle(l.t('admin_account')),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.softBorder),
            ),
            child: Column(
              children: [
                _InfoLine(l.t('admin_status'), l.t('admin_status_active')),
                const SizedBox(height: 10),
                _InfoLine(
                  l.t('admin_permissions'),
                  l.t('admin_permissions_value'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Tools ──────────────────────────────────────────────────────
          _SectionTitle(l.t('admin_tools')),
          const SizedBox(height: 10),
          _LinkRow(
            icon: Icons.auto_awesome_rounded,
            title: l.t('admin_link_ava'),
            subtitle: l.t('admin_link_ava_sub'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const AdminAssistantScreen(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _LinkRow(
            icon: Icons.local_offer_rounded,
            title: l.t('admin_link_promotions'),
            subtitle: l.t('admin_link_promotions_sub'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdminPromotionsScreen()),
            ),
          ),
          const SizedBox(height: 8),
          _LinkRow(
            icon: Icons.tune_rounded,
            title: l.t('admin_link_pricing'),
            subtitle: l.t('admin_link_pricing_sub'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdminPricingScreen()),
            ),
          ),
          const SizedBox(height: 24),

          // ── Preferences ────────────────────────────────────────────────
          _SectionTitle(l.t('preferences')),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.softBorder),
            ),
            child: Column(
              children: [
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: ThemeService.instance.mode,
                  builder: (_, mode, __) => SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: mode == ThemeMode.dark,
                    activeThumbColor: AppColors.secondary,
                    title: Text(
                      l.t('dark_mode'),
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onChanged: (v) => ThemeService.instance.setDark(v),
                  ),
                ),
                Divider(color: AppColors.softBorder, height: 1),
                ValueListenableBuilder<AppLanguage>(
                  valueListenable: LanguageService.instance.language,
                  builder: (_, lang, __) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l.t('language'),
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        for (final option in AppLanguage.values)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: GestureDetector(
                              onTap: () => LanguageService.instance
                                  .setLanguage(option),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 7),
                                decoration: BoxDecoration(
                                  color: lang == option
                                      ? AppColors.secondary
                                      : AppColors.surfaceElevated,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  option == AppLanguage.french ? 'FR' : 'EN',
                                  style: TextStyle(
                                    color: lang == option
                                        ? const Color(0xFF221A08)
                                        : AppColors.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ── Logout ─────────────────────────────────────────────────────
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () => _confirmLogout(context),
              icon: const Icon(Icons.logout_rounded, size: 19),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: BorderSide(
                    color: AppColors.danger.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              label: Text(
                l.t('logout'),
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final l = LanguageService.instance;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l.t('logout'),
            style: TextStyle(color: AppColors.textPrimary, fontSize: 17)),
        content: Text(l.t('admin_logout_confirm'),
            style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child:
                Text(l.t('cancel'), style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child:
                Text(l.t('logout'), style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (yes != true || !context.mounted) return;
    await AuthService.instance.logout();
    if (!context.mounted) return;
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }
}

class _AdminAvatar extends StatelessWidget {
  final UserModel user;

  const _AdminAvatar({required this.user});

  @override
  Widget build(BuildContext context) {
    final url = user.avatarUrl;
    final initials = user.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();

    return Container(
      width: 104,
      height: 104,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.secondary, width: 2),
      ),
      child: ClipOval(
        child: (url == null || url.isEmpty)
            ? Container(
                color: AppColors.surfaceElevated,
                alignment: Alignment.center,
                child: Text(
                  initials.isEmpty ? 'A' : initials,
                  style: TextStyle(
                    color: AppColors.secondary,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
            : FallbackNetworkImage(url: url, fit: BoxFit.cover),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: AppColors.secondary,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.6,
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;

  const _InfoLine(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _LinkRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _LinkRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.softBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: AppColors.secondary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: AppColors.textMuted, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
