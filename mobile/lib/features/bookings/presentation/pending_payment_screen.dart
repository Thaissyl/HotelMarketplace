import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../features/customer/application/customer_state.dart';
import '../../../features/customer/presentation/customer_home_screen.dart';
import '../../../shared/utils/app_formatters.dart';
import '../../../shared/widgets/app_error_presenter.dart';
import '../application/booking_controller.dart';
import '../domain/booking_models.dart';

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
  bool _isProcessingPayment = false;

  @override
  void initState() {
    super.initState();
    _remaining = _calculateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final nextRemaining = _calculateRemaining();
      if (!mounted) {
        return;
      }

      setState(() {
        _remaining = nextRemaining;
      });

      if (nextRemaining == Duration.zero && !_expiredHandled) {
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
    if (remaining.isNegative) {
      return Duration.zero;
    }

    return remaining;
  }

  Future<void> _showExpiredAndLeave() async {
    if (_isProcessingPayment) {
      return;
    }

    _timer?.cancel();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          title: const Text('Reservation expired'),
          content: const Text(
            'The temporary hold has ended. Please search again to reserve a room.',
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Back to search'),
            ),
          ],
        );
      },
    );

    if (mounted) {
      context.go(CustomerHomeScreen.routePath);
    }
  }

  Future<void> _completePayment() async {
    if (_isProcessingPayment || _remaining == Duration.zero) {
      if (_remaining == Duration.zero) {
        await _showExpiredAndLeave();
      }
      return;
    }

    setState(() => _isProcessingPayment = true);

    try {
      final result = await ref.read(bookingApiProvider).confirmDemoPayment(
            bookingId: widget.booking.id,
            amount: widget.booking.totalAmount,
          );

      if (!mounted) {
        return;
      }

      _timer?.cancel();
      ref.read(customerStateProvider.notifier).markBookingDemoPaid(
            widget.booking.id,
          );

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.lg),
            ),
            title: const Text('Payment result'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  color: AppColors.success,
                  size: 64,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  result.message.isEmpty
                      ? 'Payment successful'
                      : result.message,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                _PaymentRow(
                  label: 'Gateway reference',
                  value: result.paymentTransactionId.isEmpty
                      ? 'Not provided'
                      : result.paymentTransactionId,
                ),
                const _PaymentRow(
                  label: 'Booking status',
                  value: 'Confirmed',
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('View booking'),
              ),
            ],
          );
        },
      );

      if (mounted) {
        context.go(CustomerHomeScreen.routePath);
      }
    } catch (error) {
      if (mounted) {
        await AppErrorPresenter.showBottomSheet(context, error);
        setState(() => _isProcessingPayment = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final minutes =
        _remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds =
        _remaining.inSeconds.remainder(60).toString().padLeft(2, '0');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment instructions'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  children: [
                    Text(
                      'payOS payment instruction',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _PaymentRow(
                      label: 'Booking code',
                      value: widget.booking.bookingCode,
                    ),
                    _PaymentRow(
                      label: 'Amount',
                      value: AppFormatters.money(widget.booking.totalAmount),
                    ),
                    _PaymentRow(
                      label: 'Payment deadline',
                      value: widget.booking.paymentExpiresAtUtc == null
                          ? '15 minutes'
                          : AppFormatters.displayDate(
                              widget.booking.paymentExpiresAtUtc!,
                            ),
                    ),
                    const Divider(height: AppSpacing.xxl),
                    Text(
                      'Complete payment before the hold expires',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      '1. Review the booking code and amount.\n'
                      '2. Continue to the configured payment gateway.\n'
                      '3. Wait for the final payment result before leaving.',
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    SizedBox(
                      height: 72,
                      child: Center(
                        child: Text(
                          '$minutes:$seconds',
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall
                              ?.copyWith(
                                color: _remaining.inMinutes < 2
                                    ? AppColors.danger
                                    : AppColors.brand,
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Time remaining',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    FilledButton.icon(
                      onPressed: _isProcessingPayment ? null : _completePayment,
                      icon: const Icon(Icons.payments_outlined),
                      label: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: _isProcessingPayment
                            ? const SizedBox.square(
                                key: ValueKey('payment-loading'),
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Continue payment',
                                key: ValueKey('payment-label'),
                              ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'The current backend uses its configured demo gateway; no real charge is made.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed: () {
                        context.go(CustomerHomeScreen.routePath);
                      },
                      child: const Text('Return to booking'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          const SizedBox(width: AppSpacing.md),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        ],
      ),
    );
  }
}
