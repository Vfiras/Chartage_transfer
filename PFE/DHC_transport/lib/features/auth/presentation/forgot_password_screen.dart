import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/common/luxury_components.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendReset() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content:
              Text('Reset instructions have been queued for the admin team.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LuxuryScaffold(
      title: 'Reset Password',
      subtitle: 'Account support',
      leading: IconButton(
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.arrow_back_rounded, color: AppColors.secondary),
      ),
      body: Form(
        key: _formKey,
        child: LuxuryCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.lock_reset_rounded,
                  color: AppColors.secondary, size: 58),
              const SizedBox(height: 16),
              const Text(
                'Enter your account email. The operations team will queue reset instructions.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.45,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 22),
              LuxuryTextField(
                controller: _emailController,
                label: 'Account email',
                hintText: 'name@example.com',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Enter an email address'
                    : null,
              ),
              const SizedBox(height: 20),
              LuxuryButton(
                text: 'Send Reset Link',
                loading: _loading,
                onPressed: _sendReset,
                icon: const Icon(Icons.arrow_forward_rounded,
                    color: AppColors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
