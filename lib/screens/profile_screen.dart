import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../screens/edit_profile_screen.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/common/app_card.dart';
import '../widgets/profile_option_card.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onLogout;
  final VoidCallback? onBack;

  const ProfileScreen({super.key, this.onLogout, this.onBack});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late UserModel _user;

  @override
  void initState() {
    super.initState();
    _user = AuthService.instance.currentUser ?? AuthService.instance.demoUser;
  }

  Future<void> _editProfile() async {
    final updated = await Navigator.of(context).push<UserModel>(
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(user: _user),
      ),
    );

    if (updated != null && mounted) {
      setState(() => _user = updated);
    }
  }

  Future<void> _logout() async {
    await AuthService.instance.logout();
    if (!mounted) return;

    if (widget.onLogout != null) {
      widget.onLogout!();
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _showPlaceholder(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title is mocked for now.')),
    );
  }

  Future<void> _openSupportSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Support',
                style: AppTextStyles.h3.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose the quickest way to reach the team.',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              _SupportAction(
                icon: Icons.phone_outlined,
                title: 'Call support',
                subtitle: '+216 71 000 000',
                onTap: () => Navigator.pop(context),
              ),
              const SizedBox(height: 12),
              _SupportAction(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'WhatsApp',
                subtitle: 'Instant response',
                onTap: () => Navigator.pop(context),
              ),
              const SizedBox(height: 12),
              _SupportAction(
                icon: Icons.email_outlined,
                title: 'Email support',
                subtitle: 'support@carthagetransfer.com',
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 36),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: widget.onBack ?? () => Navigator.maybePop(context),
                              icon: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'My Profile',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.h3.copyWith(
                                  color: AppColors.textPrimary,
                                  fontSize: 22,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Profile settings coming soon.'),
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.settings_outlined,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                          AppCard(
                          padding: const EdgeInsets.all(18),
                          backgroundColor: AppColors.surface,
                          borderColor: AppColors.border,
                          radius: 28,
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x12000000),
                              blurRadius: 26,
                              offset: Offset(0, 12),
                            ),
                          ],
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _ProfileAvatar(
                                    user: _user,
                                    onEditTap: _editProfile,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _user.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTextStyles.h3.copyWith(
                                            color: AppColors.textPrimary,
                                            fontSize: 26,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _user.email,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTextStyles.body.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _user.phone,
                                          style: AppTextStyles.body.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton(
                                  onPressed: _editProfile,
                                  style: TextButton.styleFrom(
                                    backgroundColor: AppColors.secondary
                                        .withOpacity(0.12),
                                    foregroundColor: AppColors.secondary,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: const Text('Edit Profile'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                          Text(
                            'Account',
                            style: AppTextStyles.caption.copyWith(
                            color: AppColors.textMuted,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ProfileOptionCard(
                          icon: Icons.person_outline_rounded,
                          title: 'Personal Information',
                          subtitle: 'Edit name, email, and phone number',
                          onTap: _editProfile,
                        ),
                        const SizedBox(height: 12),
                        ProfileOptionCard(
                          icon: Icons.local_taxi_outlined,
                          title: 'My Bookings',
                          subtitle: 'Upcoming and past transfers',
                          onTap: () => _showPlaceholder('My Bookings'),
                        ),
                        const SizedBox(height: 12),
                        ProfileOptionCard(
                          icon: Icons.credit_card_outlined,
                          title: 'Payment Methods',
                          subtitle: 'Manage saved cards and wallets',
                          onTap: () => _showPlaceholder('Payment Methods'),
                        ),
                        const SizedBox(height: 12),
                        ProfileOptionCard(
                          icon: Icons.settings_outlined,
                          title: 'Settings',
                          subtitle: 'Preferences, privacy, and app controls',
                          onTap: () => _showPlaceholder('Settings'),
                        ),
                        const SizedBox(height: 12),
                        ProfileOptionCard(
                          icon: Icons.headset_mic_outlined,
                          title: 'Support',
                          subtitle: 'Contact the Carthage Transfer team',
                          onTap: _openSupportSheet,
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 54,
                            child: OutlinedButton.icon(
                            onPressed: _logout,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.secondary,
                              side: BorderSide(color: AppColors.secondary.withOpacity(0.4)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            icon: const Icon(Icons.logout_rounded),
                            label: const Text('Logout'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final UserModel user;
  final VoidCallback onEditTap;

  const _ProfileAvatar({
    required this.user,
    required this.onEditTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
              Container(
                  width: 88,
                  height: 88,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                AppColors.secondary.withOpacity(0.9),
                AppColors.secondaryLight.withOpacity(0.45),
                      ],
                    ),
                  ),
                  child: ClipOval(
                    child: user.avatarUrl == null
                ? Container(
                    color: AppColors.surface,
                    alignment: Alignment.center,
                    child: Text(
                      user.initials,
                      style: AppTextStyles.h3.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  )
                : Image.network(
                    user.avatarUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) {
                      return Container(
                        color: AppColors.surface,
                        alignment: Alignment.center,
                        child: Text(
                          user.initials,
                          style: AppTextStyles.h3.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
        Positioned(
          right: -2,
          bottom: 2,
          child: Material(
                color: AppColors.secondary,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: onEditTap,
                  customBorder: const CircleBorder(),
              child: const SizedBox(
                width: 28,
                height: 28,
                child: Icon(
                  Icons.edit_rounded,
                  color: AppColors.primary,
                  size: 15,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SupportAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SupportAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ProfileOptionCard(
                icon: icon,
                title: title,
                subtitle: subtitle,
                onTap: onTap,
              );
  }
}
