import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/services/auth_service.dart';
import '../models/booking_data.dart';
import '../models/vehicle.dart';
import 'booking_confirmation_screen.dart';

class ContactConfirmationScreen extends StatefulWidget {
  final BookingData data;
  final Vehicle vehicle;

  const ContactConfirmationScreen(
      {super.key, required this.data, required this.vehicle});

  @override
  State<ContactConfirmationScreen> createState() =>
      _ContactConfirmationScreenState();
}

class _ContactConfirmationScreenState extends State<ContactConfirmationScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email;
  late final TextEditingController _phone;
  bool _editingEmail = false;
  bool _editingPhone = false;

  @override
  void initState() {
    super.initState();
    final user = AuthService.instance.currentUser;
    _email = TextEditingController(
        text: AuthService.instance.isGuest ? '' : user?.email ?? '');
    _phone = TextEditingController(
        text: AuthService.instance.isGuest ? '' : user?.phone ?? '');
  }

  @override
  void dispose() {
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _continue() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    widget.data
      ..contactEmail = _email.text.trim()
      ..contactPhone = _phone.text.trim();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookingConfirmationScreen(
          data: widget.data,
          vehicle: widget.vehicle,
          totalPrice: widget.data.totalPrice,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isGuest = AuthService.instance.isGuest;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).maybePop(),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Icon(Icons.arrow_back_rounded,
                            color: AppColors.secondary, size: 20),
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'Contact Details',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    // Avatar
                    _HeaderAvatar(),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Info card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Header row
                            Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: AppColors.secondary
                                        .withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(16),
                                    border:
                                        Border.all(color: AppColors.goldBorder),
                                  ),
                                  child: Icon(
                                    isGuest
                                        ? Icons.person_outline_rounded
                                        : Icons.verified_user_outlined,
                                    color: AppColors.secondary,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Confirm your information',
                                        style: TextStyle(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                        ),
                                      ),
                                      Text(
                                        isGuest
                                            ? 'Enter details for booking updates.'
                                            : 'We will use these details for your chauffeur.',
                                        style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 12,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Email field
                            _ContactField(
                              label: 'EMAIL',
                              icon: Icons.email_outlined,
                              controller: _email,
                              isEditing: _editingEmail,
                              onChangeTap: () {
                                setState(() {
                                  _editingEmail = !_editingEmail;
                                  if (_editingEmail) {
                                    _editingPhone = false;
                                  }
                                });
                              },
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                final text = (v ?? '').trim();
                                if (text.isEmpty) return 'Required';
                                if (!text.contains('@')) {
                                  return 'Enter a valid email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            // Phone field
                            _ContactField(
                              label: 'PHONE NUMBER',
                              icon: Icons.phone_outlined,
                              controller: _phone,
                              isEditing: _editingPhone,
                              onChangeTap: () {
                                setState(() {
                                  _editingPhone = !_editingPhone;
                                  if (_editingPhone) {
                                    _editingEmail = false;
                                  }
                                });
                              },
                              keyboardType: TextInputType.phone,
                              hintText: '+216 ...',
                              validator: (v) =>
                                  (v ?? '').trim().isEmpty ? 'Required' : null,
                            ),
                            const SizedBox(height: 24),

                            // Continue button
                            GestureDetector(
                              onTap: _continue,
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.secondary,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Continue to Confirmation',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(Icons.arrow_forward_rounded,
                                        color: AppColors.primary, size: 18),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactField extends StatelessWidget {
  final String label;
  final IconData icon;
  final TextEditingController controller;
  final bool isEditing;
  final VoidCallback onChangeTap;
  final TextInputType? keyboardType;
  final String? hintText;
  final FormFieldValidator<String>? validator;

  const _ContactField({
    required this.label,
    required this.icon,
    required this.controller,
    required this.isEditing,
    required this.onChangeTap,
    this.keyboardType,
    this.hintText,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isEditing ? AppColors.secondary : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.secondary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: isEditing
                    ? TextFormField(
                        controller: controller,
                        keyboardType: keyboardType,
                        autofocus: true,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                        validator: validator,
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          hintText: hintText,
                          hintStyle: TextStyle(
                              color: AppColors.textHint, fontSize: 13),
                          contentPadding: EdgeInsets.zero,
                        ),
                      )
                    : TextFormField(
                        controller: controller,
                        enabled: false,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                        validator: validator,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
              ),
              GestureDetector(
                onTap: onChangeTap,
                child: Text(
                  isEditing ? 'DONE' : 'CHANGE',
                  style: TextStyle(
                    color: AppColors.secondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeaderAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final url = user?.avatarUrl;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surface,
        border: Border.all(color: AppColors.secondary, width: 1.5),
      ),
      child: ClipOval(
        child: (url != null && url.isNotEmpty)
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallback(),
              )
            : _fallback(),
      ),
    );
  }

  Widget _fallback() => Container(
        color: AppColors.surface,
        alignment: Alignment.center,
        child: Icon(Icons.person_rounded,
            color: AppColors.secondary, size: 22),
      );
}
