import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/language_service.dart';
import 'auth_design.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  bool _acceptTerms = true;

  @override
  void dispose() {
    _name.dispose();
    _identifier.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    final l = LanguageService.instance;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.t('terms_required'))),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await AuthService.instance.signup(
        name: _name.text.trim(),
        email: _identifier.text.trim(),
        phone: '',
        password: _password.text,
      );
      if (!mounted) return;
      Navigator.of(context)
          .pushNamedAndRemoveUntil(AppRoutes.clientShell, (route) => false);
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
        content: Text(l.t('social_signup_soon', args: {'provider': provider})),
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
          const SizedBox(height: 24),
          const AuthBackButton(),
          const SizedBox(height: 20),
          AuthTitle(
            title: l.t('create_account'),
            subtitle: l.t('signup_subtitle'),
          ),
          const SizedBox(height: 30),
          Form(
            key: _formKey,
            child: Column(
              children: [
                AuthTextField(
                  controller: _name,
                  hintText: l.t('full_name'),
                  autofillHints: const [AutofillHints.name],
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? '' : null,
                ),
                const SizedBox(height: 14),
                AuthTextField(
                  controller: _identifier,
                  hintText: l.t('email_or_phone'),
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [
                    AutofillHints.email,
                    AutofillHints.telephoneNumber,
                  ],
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? '' : null,
                ),
                const SizedBox(height: 14),
                AuthTextField(
                  controller: _password,
                  hintText: l.t('password'),
                  obscureText: _obscure,
                  suffixIcon: Icon(
                    _obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.textMuted,
                    size: 21,
                  ),
                  onSuffixTap: () => setState(() => _obscure = !_obscure),
                  validator: (value) =>
                      (value ?? '').trim().length < 4 ? '' : null,
                ),
                const SizedBox(height: 14),
                AuthTextField(
                  controller: _confirm,
                  hintText: l.t('confirm_password'),
                  obscureText: _obscure,
                  validator: (value) => value != _password.text ? '' : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 26,
                height: 26,
                child: Checkbox(
                  value: _acceptTerms,
                  activeColor: const Color(0xFFF0B33A),
                  checkColor: AppColors.primary,
                  side: BorderSide(color: AppColors.goldBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  onChanged: (value) =>
                      setState(() => _acceptTerms = value ?? false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.t('terms_accept'),
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          AuthPrimaryButton(
            text: l.t('signup'),
            loading: _loading,
            onPressed: _signup,
          ),
          const SizedBox(height: 26),
          AuthDividerLabel(text: l.t('continue_with')),
          const SizedBox(height: 18),
          AuthSocialButtons(
            onGoogle: () => _socialSoon('Google'),
          ),
          const SizedBox(height: 52),
          AuthBottomPrompt(
            text: l.t('already_have_account'),
            action: l.t('login'),
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.login),
          ),
        ],
      ),
    );
  }
}
