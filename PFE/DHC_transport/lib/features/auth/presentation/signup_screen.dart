import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/services/auth_service.dart';
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
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept the terms to continue.')),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$provider sign-up is coming soon.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageFrame(
      showImage: false,
      contentAlignment: Alignment.topCenter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          const AuthBackButton(),
          const SizedBox(height: 20),
          const AuthTitle(
            title: 'Create Account',
            subtitle: 'Sign up to get started',
          ),
          const SizedBox(height: 30),
          Form(
            key: _formKey,
            child: Column(
              children: [
                AuthTextField(
                  controller: _name,
                  hintText: 'Full Name',
                  autofillHints: const [AutofillHints.name],
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? '' : null,
                ),
                const SizedBox(height: 14),
                AuthTextField(
                  controller: _identifier,
                  hintText: 'Email or Phone Number',
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
                  hintText: 'Password',
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
                  hintText: 'Confirm Password',
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
                  side: const BorderSide(color: AppColors.goldBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  onChanged: (value) =>
                      setState(() => _acceptTerms = value ?? false),
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'I agree to the Terms & Conditions',
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
            text: 'Sign Up',
            loading: _loading,
            onPressed: _signup,
          ),
          const SizedBox(height: 26),
          const AuthDividerLabel(text: 'Or continue with'),
          const SizedBox(height: 18),
          AuthSocialButtons(
            onGoogle: () => _socialSoon('Google'),
          ),
          const SizedBox(height: 52),
          AuthBottomPrompt(
            text: 'Already have an account? ',
            action: 'Login',
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.login),
          ),
        ],
      ),
    );
  }
}
