import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/user_model.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/services/auth_service.dart';
import '../../../shared/widgets/admin/admin_card.dart';

class AdminProfileScreen extends StatelessWidget {
  const AdminProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser ??
        const UserModel(
          name: 'Admin',
          email: 'admin',
          phone: 'admin',
          role: 'admin',
        );

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 130),
        children: [
          AdminCard(
            label: user.name,
            value: 'Administrator',
            subtitle: user.email,
            icon: Icons.person_rounded,
            accentColor: AppColors.secondary,
            child: const _ProfileNote(),
          ),
          const SizedBox(height: 16),
          AdminCard(
            label: 'Account',
            value: 'Admin access',
            subtitle: 'Manage recommendations, bookings, and suppliers',
            icon: Icons.admin_panel_settings_rounded,
            child: Column(
              children: const [
                _ProfileLine('Role', 'Admin'),
                SizedBox(height: 10),
                _ProfileLine('Status', 'Active'),
                SizedBox(height: 10),
                _ProfileLine('Permissions', 'Full management access'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AdminCard(
            label: 'Session',
            value: 'Secure access',
            subtitle: 'You can sign out at any time',
            icon: Icons.logout_rounded,
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await AuthService.instance.logout();
                  if (!context.mounted) return;
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    AppRoutes.login,
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text(
                  'Logout',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileNote extends StatelessWidget {
  const _ProfileNote();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'This dashboard is reserved for trusted operations staff and recommendation management.',
      style: TextStyle(
        color: AppColors.textSecondary,
        fontSize: 14,
        height: 1.5,
      ),
    );
  }
}

class _ProfileLine extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileLine(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
