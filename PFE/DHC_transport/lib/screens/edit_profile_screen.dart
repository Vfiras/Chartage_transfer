import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/models/user_model.dart';
import '../core/services/auth_service.dart';
import '../shared/widgets/common/luxury_components.dart';

class EditProfileScreen extends StatefulWidget {
  final UserModel user;

  const EditProfileScreen({
    super.key,
    required this.user,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _emailController = TextEditingController(text: widget.user.email);
    _phoneController = TextEditingController(text: widget.user.phone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      final updated = await AuthService.instance.updateProfile(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LuxuryScaffold(
      title: 'Edit Profile',
      subtitle: 'Keep booking details accurate',
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
              Row(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surfaceElevated,
                      border: Border.all(color: AppColors.secondary),
                    ),
                    child: Text(widget.user.initials,
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'These details are used for chauffeur coordination and booking updates.',
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          height: 1.4,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              LuxuryTextField(
                controller: _nameController,
                label: 'Name',
                hintText: 'Full name',
                icon: Icons.person_outline_rounded,
                autofillHints: const [AutofillHints.name],
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? 'Enter your name' : null,
              ),
              const SizedBox(height: 16),
              LuxuryTextField(
                controller: _emailController,
                label: 'Email',
                hintText: 'name@example.com',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return 'Enter your email';
                  if (!text.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              LuxuryTextField(
                controller: _phoneController,
                label: 'Phone',
                hintText: '+216 ...',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Enter your phone number'
                    : null,
              ),
              const SizedBox(height: 22),
              LuxuryButton(
                text: 'Save Changes',
                loading: _loading,
                onPressed: _save,
                icon: const Icon(Icons.check_rounded, color: AppColors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
