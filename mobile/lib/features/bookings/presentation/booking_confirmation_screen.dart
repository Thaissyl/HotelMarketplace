import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../features/auth/application/auth_controller.dart';
import '../../../features/auth/presentation/auth_form_validators.dart';
import '../../../features/customer/application/customer_state.dart';
import '../../../features/customer/application/customer_account_providers.dart';
import '../../../shared/utils/app_formatters.dart';
import '../../../shared/widgets/app_error_presenter.dart';
import '../../../shared/widgets/app_text_form_field.dart';
import '../application/booking_controller.dart';
import '../domain/booking_draft.dart';
import '../domain/booking_models.dart';
import 'pending_payment_screen.dart';

class BookingConfirmationScreen extends ConsumerStatefulWidget {
  const BookingConfirmationScreen({
    super.key,
    required this.draft,
  });

  static const String routeName = 'booking-confirmation';
  static const String routePath = '/booking/confirm';

  final BookingDraft draft;

  @override
  ConsumerState<BookingConfirmationScreen> createState() =>
      _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState
    extends ConsumerState<BookingConfirmationScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _guestNameController;
  final _guestPhoneController = TextEditingController();
  String _paymentMode = 'PlatformCollect';

  @override
  void initState() {
    super.initState();
    final session = ref.read(authControllerProvider).userSession;
    _guestNameController = TextEditingController(
      text: session?.email.split('@').first.replaceAll('.', ' ') ?? '',
    );
    Future<void>.microtask(() async {
      try {
        final profile = await ref.read(customerProfileProvider.future);
        if (mounted) {
          _guestNameController.text = profile.fullName;
          _guestPhoneController.text = profile.phoneNumber ?? '';
        }
      } catch (_) {
        // The form remains editable when profile prefill is unavailable.
      }
    });
  }

  @override
  void dispose() {
    _guestNameController.dispose();
    _guestPhoneController.dispose();
    super.dispose();
  }

  Future<void> _confirmBooking() async {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    final booking =
        await ref.read(bookingControllerProvider.notifier).createBooking(
              CreateBookingRequest(
                hotelId: widget.draft.hotel.id,
                roomTypeId: widget.draft.roomType.id,
                checkInDate: widget.draft.query.checkInDate,
                checkOutDate: widget.draft.query.checkOutDate,
                roomCount: widget.draft.query.roomCount,
                guestCount: widget.draft.query.guestCount,
                guestFullName: _guestNameController.text,
                guestPhone: _guestPhoneController.text,
                paymentMode: _paymentMode,
              ),
            );

    if (!mounted) {
      return;
    }

    if (booking == null) {
      final error = ref.read(bookingControllerProvider).error;
      if (error != null) {
        await AppErrorPresenter.showBottomSheet(context, error);
      }
      return;
    }

    ref.read(customerStateProvider.notifier).addBooking(booking);

    final payNow = await _showBookingConfirmation(booking);
    if (!mounted) {
      return;
    }

    if (payNow == true && booking.paymentMode == 'PlatformCollect') {
      context.push(
        PendingPaymentScreen.pathFor(booking.id),
        extra: booking,
      );
      return;
    }

    context.go('/customer');
  }

  Future<bool?> _showBookingConfirmation(Booking booking) {
    final pendingPayment = booking.paymentMode == 'PlatformCollect';
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Booking confirmation'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SummaryRow(label: 'Booking code', value: booking.bookingCode),
              _SummaryRow(
                label: 'Booking status',
                value: pendingPayment ? 'Pending payment' : 'Confirmed',
              ),
              _SummaryRow(
                label: 'Payment mode',
                value: pendingPayment ? 'Platform Collect' : 'Pay at property',
              ),
              _SummaryRow(
                label: 'Room price amount',
                value: AppFormatters.money(booking.totalAmount),
              ),
              if (booking.paymentExpiresAtUtc != null)
                _SummaryRow(
                  label: 'Payment deadline',
                  value: AppFormatters.displayDate(
                    booking.paymentExpiresAtUtc!,
                  ),
                ),
            ],
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('View booking'),
            ),
            if (pendingPayment)
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Pay now'),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookingState = ref.watch(bookingControllerProvider);
    final isLoading = bookingState.isLoading;
    final draft = widget.draft;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking form'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            _BookingSummary(draft: draft),
            const SizedBox(height: AppSpacing.xl),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment mode',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'PlatformCollect',
                          icon: Icon(Icons.science_outlined),
                          label: Text('Platform Collect'),
                        ),
                        ButtonSegment(
                          value: 'PayAtProperty',
                          icon: Icon(Icons.hotel_outlined),
                          label: Text('Pay at property'),
                        ),
                      ],
                      selected: {_paymentMode},
                      onSelectionChanged: isLoading
                          ? null
                          : (selection) => setState(
                                () => _paymentMode = selection.single,
                              ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _paymentMode == 'PlatformCollect'
                          ? 'Confirm in the app before the 15-minute hold expires. No real charge is made.'
                          : 'The reservation is confirmed now and the hotel collects payment during your stay.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Contact information',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextFormField(
                        controller: _guestNameController,
                        textInputAction: TextInputAction.next,
                        validator: AuthFormValidators.fullName,
                        labelText: 'Contact name',
                        prefixIcon: const Icon(Icons.person_outline_rounded),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextFormField(
                        controller: _guestPhoneController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        validator: (value) {
                          final phoneError =
                              AuthFormValidators.phoneNumber(value);
                          if (phoneError != null) {
                            return phoneError;
                          }

                          if ((value ?? '').trim().isEmpty) {
                            return 'Contact phone is required.';
                          }

                          return null;
                        },
                        labelText: 'Contact phone',
                        prefixIcon: const Icon(Icons.phone_outlined),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Contact email',
                        ),
                        child: Text(
                          ref
                                  .watch(authControllerProvider)
                                  .userSession
                                  ?.email ??
                              '',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      FilledButton(
                        onPressed: isLoading ? null : _confirmBooking,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: isLoading
                              ? const SizedBox.square(
                                  key: ValueKey('loading'),
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Confirm booking',
                                  key: ValueKey('label'),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingSummary extends StatelessWidget {
  const _BookingSummary({required this.draft});

  final BookingDraft draft;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(draft.hotel.name, style: textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${draft.roomType.name} - ${draft.query.roomCount} room',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xl),
            _SummaryRow(
              label: 'Dates',
              value:
                  '${AppFormatters.displayDate(draft.query.checkInDate)} - ${AppFormatters.displayDate(draft.query.checkOutDate)}',
            ),
            _SummaryRow(label: 'Nights', value: '${draft.nights}'),
            _SummaryRow(label: 'Guests', value: '${draft.query.guestCount}'),
            _SummaryRow(
              label: 'Rate',
              value:
                  '${AppFormatters.money(draft.roomType.basePricePerNight)} / night',
            ),
            const Divider(height: AppSpacing.xxl),
            Row(
              children: [
                Expanded(
                  child: Text('Total', style: textTheme.titleMedium),
                ),
                Text(
                  AppFormatters.money(draft.estimatedTotal),
                  style: textTheme.titleLarge?.copyWith(
                    color: AppColors.brand,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
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
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(value, style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }
}
