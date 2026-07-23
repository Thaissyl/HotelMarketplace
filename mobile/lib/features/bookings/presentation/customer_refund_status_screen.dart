import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../shared/utils/app_formatters.dart';
import '../../../shared/widgets/srs_screen.dart';
import '../domain/booking_models.dart';
import 'customer_booking_detail_screen.dart';

class CustomerRefundStatusScreen extends StatelessWidget {
  const CustomerRefundStatusScreen({
    super.key,
    required this.booking,
  });

  static const String routeName = 'customer-refund-status';
  static const String routePath = '/bookings/:bookingId/refund';

  final Booking booking;

  static String pathFor(String bookingId) => '/bookings/$bookingId/refund';

  @override
  Widget build(BuildContext context) {
    final requestedAmount = booking.refundRequestedAmount ?? 0;
    final approvedAmount = booking.refundApprovedAmount ?? 0;
    final status = booking.refundStatus ?? 'Not Requested';

    return SrsScreen(
      title: 'Customer Refund Status Screen',
      leading: IconButton(
        tooltip: 'Back',
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(CustomerBookingDetailScreen.pathFor(booking.id));
          }
        },
        icon: const Icon(Icons.arrow_back),
      ),
      child: SrsPanel(
        child: Column(
          children: [
            SrsSummaryRow(
              label: 'Refund Eligibility',
              value: requestedAmount > 0 ? 'Eligible' : 'Not eligible',
            ),
            const Divider(height: AppSpacing.xxl),
            SrsSummaryRow(label: 'Refund Status', value: status),
            const Divider(height: AppSpacing.xxl),
            SrsSummaryRow(
              label: 'Requested Amount',
              value: AppFormatters.money(requestedAmount),
            ),
            const Divider(height: AppSpacing.xxl),
            SrsSummaryRow(
              label: 'Approved Amount',
              value: AppFormatters.money(approvedAmount),
            ),
            const Divider(height: AppSpacing.xxl),
            SrsSummaryRow(
              label: 'Customer Note',
              value: _refundNote(status),
            ),
          ],
        ),
      ),
    );
  }
}

String _refundNote(String status) {
  return switch (status) {
    'Requested' => 'Your refund request is waiting for platform review.',
    'Approved' => 'Your refund has been approved and awaits processing.',
    'Processed' => 'Your refund has been processed.',
    'Rejected' => 'Your refund request was not approved.',
    'Failed' => 'Refund processing failed. Please contact support.',
    _ => 'No refund request has been created for this booking.',
  };
}
