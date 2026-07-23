import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../features/customer/application/customer_state.dart';
import '../../../shared/utils/app_formatters.dart';
import '../../../shared/widgets/app_error_presenter.dart';
import '../../../shared/widgets/srs_screen.dart';
import '../../marketplace/presentation/marketplace_screen.dart';
import '../application/booking_controller.dart';
import '../domain/booking_models.dart';
import 'customer_booking_detail_screen.dart';
import 'payment_result_screen.dart';

class PendingPaymentScreen extends ConsumerStatefulWidget {
  const PendingPaymentScreen({
    super.key,
    required this.booking,
  });

  static const String routeName = 'pending-payment';
  static const String routePath = '/bookings/:bookingId/pending';

  final Booking booking;

  static String pathFor(String bookingId) => '/bookings/$bookingId/pending';

  @override
  ConsumerState<PendingPaymentScreen> createState() =>
      _PendingPaymentScreenState();
}

class _PendingPaymentScreenState extends ConsumerState<PendingPaymentScreen> {
  Timer? _timer;
  late Duration _remaining;
  bool _expiredHandled = false;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _remaining = _calculateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      final remaining = _calculateRemaining();
      setState(() => _remaining = remaining);
      if (remaining == Duration.zero && !_expiredHandled) {
        _expiredHandled = true;
        _showExpiredAndLeave();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Duration _calculateRemaining() {
    final expiresAt = widget.booking.paymentExpiresAtUtc;
    if (expiresAt == null) {
      return const Duration(minutes: 15);
    }
    final remaining = expiresAt.difference(DateTime.now().toUtc());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Future<void> _showExpiredAndLeave() async {
    if (_processing || !mounted) {
      return;
    }
    _timer?.cancel();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reservation expired'),
        content: const Text(
          'The temporary hold has ended. Please search again to reserve a room.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Back to Search'),
          ),
        ],
      ),
    );
    if (mounted) {
      context.go(MarketplaceScreen.routePath);
    }
  }

  Future<void> _completePayment() async {
    if (_processing) {
      return;
    }
    if (_remaining == Duration.zero) {
      await _showExpiredAndLeave();
      return;
    }

    setState(() => _processing = true);
    try {
      final result = await ref.read(bookingApiProvider).confirmDemoPayment(
            bookingId: widget.booking.id,
            amount: widget.booking.totalAmount,
          );
      if (!mounted) {
        return;
      }

      _timer?.cancel();
      ref
          .read(customerStateProvider.notifier)
          .markBookingDemoPaid(widget.booking.id);
      final confirmedBooking = widget.booking.copyWith(status: 'Confirmed');
      context.pushReplacement(
        PaymentResultScreen.pathFor(widget.booking.id),
        extra: PaymentResultArguments(
          booking: confirmedBooking,
          result: result,
        ),
      );
    } catch (error) {
      if (mounted) {
        await AppErrorPresenter.showBottomSheet(context, error);
        setState(() => _processing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final minutes =
        _remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds =
        _remaining.inSeconds.remainder(60).toString().padLeft(2, '0');

    return SrsScreen(
      title: 'Payment Instruction Screen',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SrsPanel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _InstructionRow(
                  icon: Icons.confirmation_number_outlined,
                  label: 'Booking Code',
                  value: widget.booking.bookingCode,
                ),
                const Divider(height: 1),
                _InstructionRow(
                  icon: Icons.attach_money,
                  label: 'Amount',
                  value: AppFormatters.money(widget.booking.totalAmount),
                ),
                const Divider(height: 1),
                _InstructionRow(
                  icon: Icons.calendar_month_outlined,
                  label: 'Payment Deadline',
                  value: widget.booking.paymentExpiresAtUtc == null
                      ? '15 minutes'
                      : AppFormatters.displayDateTime(
                          widget.booking.paymentExpiresAtUtc!,
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SrsPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SrsSectionTitle('Demo Payment Instruction'),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  '1. Review the booking code and amount.\n'
                  '2. Confirm the demonstration payment below.\n'
                  '3. Wait for the final booking result before leaving.',
                ),
                const SizedBox(height: AppSpacing.xl),
                Center(
                  child: Container(
                    width: 150,
                    height: 120,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSoft,
                      border: Border.all(color: AppColors.outlineSoft),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$minutes:$seconds',
                            style: Theme.of(context)
                                .textTheme
                                .displaySmall
                                ?.copyWith(
                                  color: _remaining.inMinutes < 2
                                      ? AppColors.danger
                                      : AppColors.ink,
                                ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          const Text('Time remaining'),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'This project uses a demonstration payment. No bank or real charge is involved.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: _processing ? null : _completePayment,
            child: _processing
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Continue Payment'),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            onPressed: _processing
                ? null
                : () {
                    context.go(
                      CustomerBookingDetailScreen.pathFor(widget.booking.id),
                      extra: widget.booking,
                    );
                  },
            child: const Text('Return'),
          ),
        ],
      ),
    );
  }
}

class _InstructionRow extends StatelessWidget {
  const _InstructionRow({
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
          const SizedBox(width: AppSpacing.md),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}
