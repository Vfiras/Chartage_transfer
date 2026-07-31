import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../models/booking_data.dart';
import '../models/vehicle.dart';
import '../widgets/common/luxury_cta.dart';
import 'booking_confirmation_screen.dart';

/// Payment method selection — sits between vehicle/contact selection and the
/// final booking confirmation.
///
/// Cash on arrival → the real path: the booking is created as
/// payment_status = pending_approval and confirmed later by an admin.
/// Credit card → "coming soon" placeholder: a bottom sheet explains card
/// payments are not yet available and offers to continue with cash.
class PaymentMethodScreen extends StatelessWidget {
  final BookingData data;
  final Vehicle vehicle;

  const PaymentMethodScreen({
    super.key,
    required this.data,
    required this.vehicle,
  });

  void _continueWith(BuildContext context, String method) {
    data.paymentMethod = method;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookingConfirmationScreen(
          data: data,
          vehicle: vehicle,
          totalPrice: data.totalPrice,
        ),
      ),
    );
  }

  void _showCardComingSoon(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.credit_card_rounded,
                color: AppColors.secondary, size: 40),
            const SizedBox(height: 14),
            Text(
              'Card payments coming soon',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Card payments will be available in a future update. '
              'You can complete your booking with cash in the meantime.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 22),
            LuxuryCta(
              text: 'Continue with Cash',
              onTap: () {
                Navigator.of(sheetContext).pop();
                _continueWith(context, 'cash');
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(Icons.arrow_back_rounded,
                        color: AppColors.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Payment Method',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose how you\'d like to pay for your transfer '
                '(${data.totalPrice.toStringAsFixed(0)} ${data.currency}).',
                style: TextStyle(color: AppColors.textMuted, fontSize: 14),
              ),
              const SizedBox(height: 28),
              _PaymentOptionCard(
                icon: Icons.payments_rounded,
                title: 'Pay with Cash',
                subtitle: 'Your booking will be reviewed and confirmed by '
                    'our team within a few hours.',
                badge: 'Requires Approval',
                badgeColor: AppColors.secondary,
                onTap: () => _continueWith(context, 'cash'),
              ),
              const SizedBox(height: 16),
              _PaymentOptionCard(
                icon: Icons.credit_card_rounded,
                title: 'Pay by Card',
                subtitle: 'Online card payment — coming soon.',
                badge: 'Coming Soon',
                badgeColor: AppColors.textMuted,
                muted: true,
                onTap: () => _showCardComingSoon(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;
  final bool muted;
  final VoidCallback onTap;

  const _PaymentOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeColor,
    this.muted = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor =
        muted ? AppColors.textPrimary.withValues(alpha: 0.55) : AppColors.textPrimary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: muted ? AppColors.softBorder : AppColors.goldBorder,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondary
                    .withValues(alpha: muted ? 0.06 : 0.14),
              ),
              child: Icon(icon,
                  color: muted
                      ? AppColors.textMuted
                      : AppColors.secondary,
                  size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: titleColor,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          badge.toUpperCase(),
                          style: TextStyle(
                            color: badgeColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.7,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppColors.textSecondary
                          .withValues(alpha: muted ? 0.6 : 1),
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
