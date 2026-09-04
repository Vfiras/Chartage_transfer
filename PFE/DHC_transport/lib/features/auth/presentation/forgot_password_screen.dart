import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/language_service.dart';
import '../../../shared/widgets/common/luxury_components.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _tokenController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;

  /// Revealed after a link is requested. The emailed link points at a web URL,
  /// so entering the token here is what makes the reset completable in-app —
  /// and demonstrable when SMTP is not configured.
  bool _linkRequested = false;

  @override
  void dispose() {
    _emailController.dispose();
    _tokenController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _sendReset() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      final message =
          await AuthService.instance.requestPasswordReset(_emailController.text);
      if (!mounted) return;
      setState(() => _linkRequested = true);
      _toast(message);
    } catch (e) {
      _toast(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _applyReset() async {
    final l = LanguageService.instance;
    if (_tokenController.text.trim().isEmpty ||
        _passwordController.text.length < 6) {
      _toast(l.t('reset_password_needs_token'));
      return;
    }
    setState(() => _loading = true);
    try {
      final message = await AuthService.instance.resetPassword(
        token: _tokenController.text,
        newPassword: _passwordController.text,
      );
      if (!mounted) return;
      _toast(message);
      Navigator.of(context).maybePop();
    } catch (e) {
      _toast(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;

    return LuxuryScaffold(
      title: l.t('reset_password'),
      subtitle: l.t('support'),
      leading: IconButton(
        onPressed: () => Navigator.of(context).maybePop(),
        icon: Icon(Icons.arrow_back_rounded, color: AppColors.secondary),
      ),
      body: Form(
        key: _formKey,
        child: LuxuryCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.lock_reset_rounded,
                  color: AppColors.secondary, size: 58),
              const SizedBox(height: 16),
              Text(
                l.t('reset_password_body'),
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.45,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 22),
              LuxuryTextField(
                controller: _emailController,
                label: l.t('reset_email_label'),
                hintText: 'name@example.com',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                // The endpoint keys off email only, so reject a phone number
                // here rather than let the user wait for mail that never comes.
                validator: (value) {
                  final v = (value ?? '').trim();
                  final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v);
                  return ok ? null : l.t('reset_email_invalid');
                },
              ),
              const SizedBox(height: 20),
              LuxuryButton(
                text: l.t('send_reset_link'),
                loading: _loading && !_linkRequested,
                onPressed: _sendReset,
                icon:
                    Icon(Icons.arrow_forward_rounded, color: AppColors.primary),
              ),
              if (_linkRequested) ...[
                const SizedBox(height: 26),
                Divider(color: AppColors.border, height: 1),
                const SizedBox(height: 22),
                Text(
                  l.t('reset_password_step2'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.45,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                LuxuryTextField(
                  controller: _tokenController,
                  label: l.t('reset_password_token'),
                  hintText: 'e.g. 8Kf2...',
                  icon: Icons.vpn_key_outlined,
                ),
                const SizedBox(height: 14),
                LuxuryTextField(
                  controller: _passwordController,
                  label: l.t('reset_password_new'),
                  hintText: '******',
                  icon: Icons.lock_outline_rounded,
                  obscureText: true,
                ),
                const SizedBox(height: 18),
                LuxuryButton(
                  text: l.t('reset_password_apply'),
                  loading: _loading && _linkRequested,
                  onPressed: _applyReset,
                  icon: Icon(Icons.check_rounded, color: AppColors.primary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
