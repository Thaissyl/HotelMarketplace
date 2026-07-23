import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../features/customer/application/customer_state.dart';
import '../../../shared/utils/app_formatters.dart';
import '../../../shared/widgets/app_error_presenter.dart';
import '../../../shared/widgets/app_text_form_field.dart';
import '../../../shared/widgets/srs_screen.dart';
import '../application/booking_controller.dart';
import '../domain/booking_models.dart';
import 'customer_refund_status_screen.dart';
import 'my_bookings_screen.dart';
import 'pending_payment_screen.dart';

class CustomerBookingDetailScreen extends ConsumerStatefulWidget {
  const CustomerBookingDetailScreen({
    super.key,
    required this.booking,
  });

  static const String routeName = 'customer-booking-detail';
  static const String routePath = '/bookings/:bookingId';

  final Booking booking;

  static String pathFor(String bookingId) => '/bookings/$bookingId';

  @override
  ConsumerState<CustomerBookingDetailScreen> createState() =>
      _CustomerBookingDetailScreenState();
}

class _CustomerBookingDetailScreenState
    extends ConsumerState<CustomerBookingDetailScreen> {
  late final Future<BookingCancellationQuote> _quote;

  @override
  void initState() {
    super.initState();
    _quote =
        ref.read(bookingApiProvider).getCancellationQuote(widget.booking.id);
  }

  Future<void> _cancelBooking(BookingCancellationQuote quote) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _CancellationSheet(
        bookingCode: widget.booking.bookingCode,
        quote: quote,
      ),
    );
    if (reason == null || !mounted) {
      return;
    }

    try {
      final result = await ref.read(bookingApiProvider).cancelBooking(
            bookingId: widget.booking.id,
            reason: reason,
          );
      ref
          .read(customerStateProvider.notifier)
          .markBookingCancelled(widget.booking.id);
      ref.invalidate(myBookingsProvider);
      if (mounted) {
        AppErrorPresenter.showSnackBar(context, result.summary);
        context.go(MyBookingsScreen.routePath);
      }
    } catch (error) {
      if (mounted) {
        await AppErrorPresenter.showBottomSheet(
          context,
          error,
          title: 'Cancellation not completed',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;

    return SrsScreen(
      title: 'Customer Booking Detail Screen',
      leading: IconButton(
        tooltip: 'Back',
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(MyBookingsScreen.routePath);
          }
        },
        icon: const Icon(Icons.arrow_back),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SrsSectionTitle('Booking Summary'),
          const SizedBox(height: AppSpacing.sm),
          SrsPanel(
            child: Column(
              children: [
                SrsSummaryRow(
                  label: 'Booking Code',
                  value: booking.bookingCode,
                ),
                SrsSummaryRow(
                  label: 'Hotel',
                  value: booking.hotelName ?? 'Hotel information unavailable',
                ),
                SrsSummaryRow(
                  label: 'Room Type',
                  value: booking.roomTypeName ?? 'Room information unavailable',
                ),
                SrsSummaryRow(
                  label: 'Check-in',
                  value: AppFormatters.displayDate(booking.checkInDate),
                ),
                SrsSummaryRow(
                  label: 'Check-out',
                  value: AppFormatters.displayDate(booking.checkOutDate),
                ),
                SrsSummaryRow(
                  label: 'Guests / Rooms',
                  value: '${booking.guestCount} / ${booking.roomCount}',
                ),
                SrsSummaryRow(label: 'Status', value: booking.status),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const SrsSectionTitle('Receipt Summary'),
          const SizedBox(height: AppSpacing.sm),
          SrsPanel(
            child: Column(
              children: [
                SrsSummaryRow(
                  label: 'Nightly Rate',
                  value: AppFormatters.money(booking.unitPricePerNight),
                ),
                SrsSummaryRow(label: 'Nights', value: '${booking.nights}'),
                SrsSummaryRow(
                  label: 'Total',
                  value: AppFormatters.money(booking.totalAmount),
                  emphasized: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const SrsSectionTitle('Payment Status'),
          const SizedBox(height: AppSpacing.sm),
          SrsPanel(
            child: Column(
              children: [
                SrsSummaryRow(
                  label: 'Payment Mode',
                  value: booking.paymentMode == 'PlatformCollect'
                      ? 'Demo Payment'
                      : 'Pay at Property',
                ),
                SrsSummaryRow(
                  label: 'Payment Status',
                  value: _paymentStatus(booking),
                ),
                if (booking.paymentExpiresAtUtc != null)
                  SrsSummaryRow(
                    label: 'Payment Deadline',
                    value: AppFormatters.displayDateTime(
                      booking.paymentExpiresAtUtc!,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const SrsSectionTitle('Cancellation Policy'),
          const SizedBox(height: AppSpacing.sm),
          FutureBuilder<BookingCancellationQuote>(
            future: _quote,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const LinearProgressIndicator();
              }
              if (!snapshot.hasData) {
                return const SrsPanel(
                  child: Text(
                    'Cancellation policy is unavailable for this booking.',
                  ),
                );
              }

              final quote = snapshot.data!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SrsPanel(
                    child: Column(
                      children: [
                        SrsSummaryRow(
                          label: 'Policy',
                          value: quote.policyName ?? 'Standard policy',
                        ),
                        SrsSummaryRow(
                          label: 'Cancellation',
                          value: quote.canCancel ? 'Allowed' : 'Not allowed',
                        ),
                        SrsSummaryRow(
                          label: 'Estimated Refund',
                          value: AppFormatters.money(
                            quote.estimatedRefundAmount,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const SrsSectionTitle('Allowed Actions'),
                  const SizedBox(height: AppSpacing.sm),
                  if (booking.status == 'PendingPayment') ...[
                    FilledButton(
                      onPressed: () {
                        context.push(
                          PendingPaymentScreen.pathFor(booking.id),
                          extra: booking,
                        );
                      },
                      child: const Text('Retry Payment'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  if (quote.canCancel)
                    OutlinedButton(
                      onPressed: () => _cancelBooking(quote),
                      child: const Text('Cancel Booking'),
                    ),
                  if (booking.refundStatus != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton(
                      onPressed: () {
                        context.push(
                          CustomerRefundStatusScreen.pathFor(booking.id),
                          extra: booking,
                        );
                      },
                      child: const Text('View Refund Status'),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CancellationSheet extends StatefulWidget {
  const _CancellationSheet({
    required this.bookingCode,
    required this.quote,
  });

  final String bookingCode;
  final BookingCancellationQuote quote;

  @override
  State<_CancellationSheet> createState() => _CancellationSheetState();
}

class _CancellationSheetState extends State<_CancellationSheet> {
  final _reason = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _reason.text.trim();
    if (reason.length < 3) {
      setState(() => _errorText = 'Enter a clear cancellation reason.');
      return;
    }
    Navigator.of(context).pop(reason);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Cancel ${widget.bookingCode}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(widget.quote.summary),
            const SizedBox(height: AppSpacing.lg),
            AppTextFormField(
              controller: _reason,
              labelText: 'Cancellation Reason',
              externalLabel: true,
              required: true,
              errorText: _errorText,
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: widget.quote.canCancel ? _submit : null,
              child: const Text('Confirm Cancellation'),
            ),
          ],
        ),
      ),
    );
  }
}

String _paymentStatus(Booking booking) {
  if (booking.status == 'PendingPayment') {
    return 'Pending';
  }
  if (booking.paymentMode == 'PayAtProperty') {
    return 'Pay at Property';
  }
  if (booking.status == 'Confirmed' ||
      booking.status == 'CheckedIn' ||
      booking.status == 'Completed') {
    return 'Processed';
  }
  return 'Not collected';
}
