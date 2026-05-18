import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/services/auth_service.dart';
import '../models/booking_data.dart';
import '../models/vehicle.dart';
import '../shared/widgets/common/luxury_components.dart';
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
    return LuxuryScaffold(
      title: 'Contact Details',
      subtitle: isGuest ? 'Guest checkout' : 'Confirm your information',
      leading: IconButton(
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.arrow_back_rounded, color: AppColors.secondary),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LuxuryCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.goldBorder),
                        ),
                        child: Icon(
                            isGuest
                                ? Icons.person_outline_rounded
                                : Icons.verified_user_outlined,
                            color: AppColors.secondary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          isGuest
                              ? 'Enter details for booking updates.'
                              : 'We will use these details for your chauffeur.',
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              height: 1.4,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  LuxuryTextField(
                    controller: _email,
                    label: 'Email',
                    hintText: 'name@example.com',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      final text = (value ?? '').trim();
                      if (text.isEmpty) return 'Required';
                      if (!text.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  LuxuryTextField(
                    controller: _phone,
                    label: 'Phone number',
                    hintText: '+216 ...',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    validator: (value) =>
                        (value ?? '').trim().isEmpty ? 'Required' : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            LuxuryButton(
              text: 'Continue to Confirmation',
              onPressed: _continue,
              icon: const Icon(Icons.arrow_forward_rounded,
                  color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
