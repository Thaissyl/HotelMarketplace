import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../features/auth/application/auth_controller.dart';
import '../../../features/auth/presentation/auth_form_validators.dart';
import '../../../shared/utils/app_formatters.dart';
import '../../../shared/widgets/app_error_presenter.dart';
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

  @override
  void initState() {
    super.initState();
    final session = ref.read(authControllerProvider).userSession;
    _guestNameController = TextEditingController(
      text: session?.email.split('@').first.replaceAll('.', ' ') ?? '',
    );
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

    context.go(
      PendingPaymentScreen.pathFor(booking.id),
      extra: booking,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookingState = ref.watch(bookingControllerProvider);
    final isLoading = bookingState.isLoading;
    final draft = widget.draft;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm booking'),
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
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Guest information',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _guestNameController,
                        textInputAction: TextInputAction.next,
                        validator: AuthFormValidators.fullName,
                        decoration: const InputDecoration(
                          labelText: 'Guest full name',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
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
                            return 'Guest phone is required.';
                          }

                          return null;
                        },
                        decoration: const InputDecoration(
                          labelText: 'Guest phone',
                          prefixIcon: Icon(Icons.phone_outlined),
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
                                  'Confirm reservation',
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
              '${draft.roomType.name} · ${draft.query.roomCount} room',
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
