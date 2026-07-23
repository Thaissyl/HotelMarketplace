import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../shared/utils/app_formatters.dart';
import '../../../shared/widgets/srs_screen.dart';
import '../domain/booking_models.dart';
import 'customer_booking_detail_screen.dart';
import 'pending_payment_screen.dart';

class BookingConfirmationScreen extends StatelessWidget {
  const BookingConfirmationScreen({
    super.key,
    required this.booking,
  });

  static const String routeName = 'booking-confirmation';
  static const String routePath = '/booking/confirmation/:bookingId';

  final Booking booking;

  static String pathFor(String bookingId) => '/booking/confirmation/$bookingId';

  @override
  Widget build(BuildContext context) {
    final pendingPayment =
        booking.paymentMode == 'PlatformCollect' && booking.isPendingPayment;

    return SrsScreen(
      title: 'Booking Confirmation Screen',
      automaticallyImplyLeading: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SrsPanel(
            child: Column(
              children: [
                SrsSummaryRow(
                  label: 'Booking Code',
                  value: booking.bookingCode,
                ),
                const Divider(height: AppSpacing.xxl),
                SrsSummaryRow(
                  label: 'Booking Status',
                  value: booking.status,
                ),
                const Divider(height: AppSpacing.xxl),
                SrsSummaryRow(
                  label: 'Payment Mode',
                  value: booking.paymentMode == 'PlatformCollect'
                      ? 'Demo Payment'
                      : 'Pay at Property',
                ),
                const Divider(height: AppSpacing.xxl),
                SrsSummaryRow(
                  label: 'Room Price Amount',
                  value: AppFormatters.money(booking.totalAmount),
                ),
                const Divider(height: AppSpacing.xxl),
                SrsSummaryRow(
                  label: 'Payment Deadline',
                  value: booking.paymentExpiresAtUtc == null
                      ? 'Not applicable'
                      : AppFormatters.displayDateTime(
                          booking.paymentExpiresAtUtc!,
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          if (pendingPayment) ...[
            FilledButton(
              onPressed: () {
                context.pushReplacement(
                  PendingPaymentScreen.pathFor(booking.id),
                  extra: booking,
                );
              },
              child: const Text('Pay Now'),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          OutlinedButton(
            onPressed: () {
              context.pushReplacement(
                CustomerBookingDetailScreen.pathFor(booking.id),
                extra: booking,
              );
            },
            child: const Text('View Booking'),
          ),
        ],
      ),
    );
  }
}
