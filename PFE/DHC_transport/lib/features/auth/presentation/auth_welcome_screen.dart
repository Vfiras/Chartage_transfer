import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/language_service.dart';
import 'auth_design.dart';

class AuthWelcomeScreen extends StatelessWidget {
  const AuthWelcomeScreen({super.key});

  void _continueAsGuest(BuildContext context) {
    AuthService.instance.continueAsGuest();
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.clientShell, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;

    return AuthScaffold(
      imageAlignment: Alignment.bottomCenter,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final topGap =
              (constraints.maxHeight * 0.055).clamp(34.0, 54.0).toDouble();
          final brandToButtonsGap =
              (constraints.maxHeight * 0.335).clamp(230.0, 318.0).toDouble();

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - 40)
                    .clamp(0.0, double.infinity)
                    .toDouble(),
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: topGap),
                      const AuthBrandLockup(stacked: true),
                      const SizedBox(height: 22),
                      Text(
                        '${l.t('premium_rides')}.\n${l.t('every_time')}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          height: 1.55,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: brandToButtonsGap),
                      AuthPrimaryButton(
                        text: l.t('login_or_register'),
                        onPressed: () =>
                            Navigator.of(context).pushNamed(AppRoutes.login),
                      ),
                      const SizedBox(height: 14),
                      AuthOutlineButton(
                        text: l.t('guest_browsing'),
                        onPressed: () => _continueAsGuest(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
