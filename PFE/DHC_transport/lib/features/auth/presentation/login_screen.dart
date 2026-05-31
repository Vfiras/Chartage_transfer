import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/language_service.dart';
import 'auth_design.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      final user = await AuthService.instance.login(
        identifier: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (!mounted) return;
      final route = user.role.toLowerCase() == 'admin'
          ? AppRoutes.adminShell
          : AppRoutes.clientShell;
      Navigator.of(context).pushNamedAndRemoveUntil(route, (route) => false);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _socialSoon(String provider) {
    final l = LanguageService.instance;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l.t('social_login_soon', args: {'provider': provider})),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;

    return AuthPageFrame(
      showImage: false,
      contentAlignment: Alignment.topCenter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 38),
          const AuthBackButton(),
          const SizedBox(height: 18),
          Image.asset(
            'assets/images/logo.png',
            height: 38,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
          const SizedBox(height: 28),
          AuthTitle(
            title: l.t('welcome_back'),
            subtitle: l.t('login_subtitle'),
          ),
          const SizedBox(height: 30),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthTextField(
                  controller: _emailController,
                  hintText: l.t('email_or_phone'),
                  autofillHints: const [
                    AutofillHints.username,
                    AutofillHints.email,
                    AutofillHints.telephoneNumber,
                  ],
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? '' : null,
                ),
                const SizedBox(height: 14),
                AuthTextField(
                  controller: _passwordController,
                  hintText: l.t('password'),
                  obscureText: _obscurePassword,
                  suffixIcon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.textMuted,
                    size: 21,
                  ),
                  onSuffixTap: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? '' : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.forgotPassword),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                l.t('forgot_password'),
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          AuthPrimaryButton(
            text: l.t('login'),
            loading: _loading,
            onPressed: _handleLogin,
          ),
          const SizedBox(height: 26),
          AuthDividerLabel(text: l.t('continue_with')),
          const SizedBox(height: 18),
          AuthSocialButtons(
            onGoogle: () => _socialSoon('Google'),
          ),
          const SizedBox(height: 62),
          AuthBottomPrompt(
            text: l.t('no_account'),
            action: l.t('signup'),
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.signup),
          ),
        ],
      ),
    );
  }
}
