import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
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
    final status = _RefundDisplayStatus.fromApiValue(booking.refundStatus);
    final hasRefundRequest =
        booking.refundStatus != null || requestedAmount > 0;

    return SrsScreen(
      title: 'Customer Refund Status Screen',
      titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: 20,
          ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RefundInformationCard(
            icon: Icons.verified_user_outlined,
            iconShape: BoxShape.rectangle,
            title: 'Refund Eligibility',
            badge: hasRefundRequest ? 'Eligible' : 'Not Eligible',
            badgeTone:
                hasRefundRequest ? _BadgeTone.success : _BadgeTone.neutral,
            description: hasRefundRequest
                ? 'This cancellation qualified for a refund under the hotel policy.'
                : 'No refundable cancellation is recorded for this booking.',
          ),
          const SizedBox(height: AppSpacing.md),
          _RefundInformationCard(
            icon: Icons.history_rounded,
            iconShape: BoxShape.circle,
            title: 'Refund Status',
            badge: status.label,
            badgeTone: status.badgeTone,
            description: status.description,
          ),
          const SizedBox(height: AppSpacing.md),
          _RefundInformationCard(
            icon: Icons.account_balance_wallet_outlined,
            iconShape: BoxShape.rectangle,
            title: 'Requested Amount',
            badge: AppFormatters.money(requestedAmount),
            badgeTone: _BadgeTone.neutral,
            description: hasRefundRequest
                ? 'Amount submitted for review for booking ${booking.bookingCode}.'
                : 'No refund amount has been requested.',
          ),
          const SizedBox(height: AppSpacing.md),
          _RefundInformationCard(
            icon: Icons.check_circle_outline_rounded,
            iconShape: BoxShape.rectangle,
            title: 'Approved Amount',
            badge: AppFormatters.money(approvedAmount),
            badgeTone:
                approvedAmount > 0 ? _BadgeTone.success : _BadgeTone.neutral,
            description: _approvedAmountDescription(
              status,
              approvedAmount,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SrsPanel(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Customer Note',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 132),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  child: Text(
                    status.customerNote,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.mutedInk,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RefundInformationCard extends StatelessWidget {
  const _RefundInformationCard({
    required this.icon,
    required this.iconShape,
    required this.title,
    required this.badge,
    required this.badgeTone,
    required this.description,
  });

  final IconData icon;
  final BoxShape iconShape;
  final String title;
  final String badge;
  final _BadgeTone badgeTone;
  final String description;

  @override
  Widget build(BuildContext context) {
    return SrsPanel(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 104),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                shape: iconShape,
                borderRadius: iconShape == BoxShape.rectangle
                    ? BorderRadius.circular(AppRadii.sm)
                    : null,
              ),
              child: Icon(
                icon,
                size: 36,
                color: AppColors.brandDark,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    fontSize: 15,
                                  ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _RefundBadge(
                        label: badge,
                        tone: badgeTone,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium,
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

class _RefundBadge extends StatelessWidget {
  const _RefundBadge({
    required this.label,
    required this.tone,
  });

  final String label;
  final _BadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final (backgroundColor, foregroundColor) = switch (tone) {
      _BadgeTone.success => (AppColors.successSoft, AppColors.success),
      _BadgeTone.warning => (AppColors.warningSoft, AppColors.warning),
      _BadgeTone.danger => (
          const Color(0xFFFDECEC),
          AppColors.danger,
        ),
      _BadgeTone.neutral => (AppColors.surfaceSoft, AppColors.brandDark),
    };

    return Container(
      constraints: const BoxConstraints(minWidth: 88),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

enum _BadgeTone {
  success,
  warning,
  danger,
  neutral,
}

enum _RefundDisplayStatus {
  pendingReview(
    label: 'Pending Review',
    badgeTone: _BadgeTone.warning,
    description: 'The platform team is reviewing your refund request.',
    customerNote:
        'Your refund request has been received. The platform team will review the cancellation details and update the approved amount when a decision is made.',
  ),
  approved(
    label: 'Approved',
    badgeTone: _BadgeTone.success,
    description: 'The approved refund is waiting to be processed.',
    customerNote:
        'Your refund request has been approved. The approved amount is shown above and is waiting for the demonstration refund process to complete.',
  ),
  processed(
    label: 'Processed',
    badgeTone: _BadgeTone.success,
    description: 'The refund process has been completed.',
    customerNote:
        'Your refund has been processed successfully. This project uses the demonstration payment flow and does not contact a real bank.',
  ),
  rejected(
    label: 'Rejected',
    badgeTone: _BadgeTone.danger,
    description: 'The refund request was not approved.',
    customerNote:
        'Your refund request was not approved under the applicable cancellation policy. Contact support if you need clarification.',
  ),
  failed(
    label: 'Failed',
    badgeTone: _BadgeTone.danger,
    description: 'The refund process could not be completed.',
    customerNote:
        'Refund processing failed. Contact support so the platform team can review the request and determine the next action.',
  ),
  notRequested(
    label: 'Not Requested',
    badgeTone: _BadgeTone.neutral,
    description: 'No refund request exists for this booking.',
    customerNote:
        'No refund request has been created for this booking. Refund information will appear here after an eligible cancellation creates a request.',
  );

  const _RefundDisplayStatus({
    required this.label,
    required this.badgeTone,
    required this.description,
    required this.customerNote,
  });

  final String label;
  final _BadgeTone badgeTone;
  final String description;
  final String customerNote;

  static _RefundDisplayStatus fromApiValue(String? value) {
    return switch (value) {
      'PendingReview' || 'Requested' => pendingReview,
      'Approved' => approved,
      'Processed' => processed,
      'Rejected' => rejected,
      'Failed' => failed,
      _ => notRequested,
    };
  }
}

String _approvedAmountDescription(
  _RefundDisplayStatus status,
  double approvedAmount,
) {
  if (approvedAmount > 0) {
    return status == _RefundDisplayStatus.processed
        ? 'Amount completed through the demonstration refund flow.'
        : 'Amount approved by the platform team.';
  }

  return switch (status) {
    _RefundDisplayStatus.pendingReview =>
      'The approved amount will appear after platform review.',
    _RefundDisplayStatus.rejected => 'No amount was approved for this request.',
    _RefundDisplayStatus.failed => 'No completed refund amount is available.',
    _ => 'No approved refund amount is available.',
  };
}
