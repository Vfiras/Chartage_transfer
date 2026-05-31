import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/models/user_model.dart';
import '../core/services/auth_service.dart';
import '../shared/widgets/client/premium_profile_components.dart';

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
  bool _saving = false;
  bool _uploadingAvatar = false;
  late UserModel _user;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
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

  Future<void> _pickAvatar() async {
    if (!AuthService.instance.isAuthenticated || _uploadingAvatar) return;
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1600,
    );
    if (file == null) return;

    setState(() => _uploadingAvatar = true);
    try {
      final updated = await AuthService.instance.uploadAvatar(file);
      if (!mounted) return;
      setState(() => _user = updated);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false) || _saving) return;
    setState(() => _saving = true);
    try {
      final updated = await AuthService.instance.updateProfile(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PremiumProfilePalette.background(context),
      body: PremiumProfileBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 34),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PremiumProfileTopBar(
                    title: 'CARTHAGE TRANSFER',
                    showMenu: false,
                    onLeadingTap: () => Navigator.of(context).maybePop(),
                    trailing: const SizedBox(width: 26),
                  ),
                  const SizedBox(height: 40),
                  Center(
                    child: PremiumProfileAvatar(
                      user: _user,
                      size: 128,
                      onEditTap: _uploadingAvatar ? null : _pickAvatar,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _user.name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: PremiumProfilePalette.text(context),
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _uploadingAvatar
                        ? 'Uploading portrait...'
                        : 'Keep your chauffeur details polished and up to date.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: PremiumProfilePalette.subtitle(context),
                      fontSize: 14,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 40),
                  PremiumProfileTextField(
                    label: 'Full Name',
                    controller: _nameController,
                    icon: Icons.person_outline_rounded,
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? 'Enter your full name'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  PremiumProfileTextField(
                    label: 'Email Address',
                    controller: _emailController,
                    icon: Icons.alternate_email_rounded,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      final text = (value ?? '').trim();
                      if (text.isEmpty) return 'Enter your email';
                      if (!text.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  PremiumProfileTextField(
                    label: 'Phone Number',
                    controller: _phoneController,
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? 'Enter your phone number'
                        : null,
                  ),
                  const SizedBox(height: 36),
                  PremiumProfilePrimaryButton(
                    text: _saving ? 'Saving...' : 'Save Profile',
                    onTap: _saving ? null : _save,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
