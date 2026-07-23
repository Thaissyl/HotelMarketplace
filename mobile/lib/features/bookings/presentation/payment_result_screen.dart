import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../shared/widgets/srs_screen.dart';
import '../domain/booking_models.dart';
import 'customer_booking_detail_screen.dart';
import 'pending_payment_screen.dart';

class PaymentResultArguments {
  const PaymentResultArguments({
    required this.booking,
    required this.result,
  });

  final Booking booking;
  final DemoPaymentResult result;
}

class PaymentResultScreen extends StatelessWidget {
  const PaymentResultScreen({
    super.key,
    required this.arguments,
  });

  static const String routeName = 'payment-result';
  static const String routePath = '/bookings/:bookingId/payment-result';

  final PaymentResultArguments arguments;

  static String pathFor(String bookingId) =>
      '/bookings/$bookingId/payment-result';

  @override
  Widget build(BuildContext context) {
    final success = arguments.result.isProcessed;

    return SrsScreen(
      title: 'Payment Result Screen',
      automaticallyImplyLeading: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SrsPanel(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Column(
                children: [
                  const SrsSectionTitle('Payment Result'),
                  const SizedBox(height: AppSpacing.xl),
                  Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.outline, width: 2),
                    ),
                    child: Icon(
                      success ? Icons.check : Icons.close,
                      size: 64,
                      color: success ? AppColors.success : AppColors.danger,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    arguments.result.message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SrsPanel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _ResultRow(
                  icon: Icons.receipt_long_outlined,
                  label: 'Gateway Reference',
                  value: arguments.result.paymentTransactionId.isEmpty
                      ? 'Not provided'
                      : arguments.result.paymentTransactionId,
                ),
                const Divider(height: 1),
                _ResultRow(
                  icon: Icons.calendar_month_outlined,
                  label: 'Booking Status',
                  value: arguments.booking.status,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          if (!success) ...[
            FilledButton(
              onPressed: () {
                context.pushReplacement(
                  PendingPaymentScreen.pathFor(arguments.booking.id),
                  extra: arguments.booking,
                );
              },
              child: const Text('Retry Payment'),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          OutlinedButton(
            onPressed: () {
              context.pushReplacement(
                CustomerBookingDetailScreen.pathFor(arguments.booking.id),
                extra: arguments.booking,
              );
            },
            child: const Text('View Booking'),
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            color: AppColors.surfaceSoft,
            child: Icon(icon),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          Flexible(
            child: Text(value, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}
