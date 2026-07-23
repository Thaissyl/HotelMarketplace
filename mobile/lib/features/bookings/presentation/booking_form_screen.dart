import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../features/auth/application/auth_controller.dart';
import '../../../features/auth/presentation/auth_form_validators.dart';
import '../../../features/customer/application/customer_account_providers.dart';
import '../../../features/customer/application/customer_state.dart';
import '../../../shared/utils/app_formatters.dart';
import '../../../shared/widgets/app_error_presenter.dart';
import '../../../shared/widgets/app_text_form_field.dart';
import '../../../shared/widgets/srs_screen.dart';
import '../application/booking_controller.dart';
import '../domain/booking_draft.dart';
import '../domain/booking_models.dart';
import 'booking_confirmation_screen.dart';

class BookingFormScreen extends ConsumerStatefulWidget {
  const BookingFormScreen({super.key, required this.draft});

  static const String routeName = 'booking-form';
  static const String routePath = '/booking/new';

  final BookingDraft draft;

  @override
  ConsumerState<BookingFormScreen> createState() => _BookingFormScreenState();
}

class _BookingFormScreenState extends ConsumerState<BookingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _contactName;
  final _contactPhone = TextEditingController();
  late final TextEditingController _contactEmail;
  late DateTime _checkInDate;
  late DateTime _checkOutDate;
  late int _roomQuantity;
  late int _guestCount;
  String _paymentMode = 'PlatformCollect';

  @override
  void initState() {
    super.initState();
    final session = ref.read(authControllerProvider).userSession;
    _contactName = TextEditingController();
    _contactEmail = TextEditingController(text: session?.email ?? '');
    _checkInDate = widget.draft.query.checkInDate;
    _checkOutDate = widget.draft.query.checkOutDate;
    _roomQuantity = widget.draft.query.roomCount.clamp(
      1,
      widget.draft.roomType.availableRoomCount,
    );
    _guestCount = widget.draft.query.guestCount;

    Future<void>.microtask(() async {
      try {
        final profile = await ref.read(customerProfileProvider.future);
        if (mounted) {
          _contactName.text = profile.fullName;
          _contactPhone.text = profile.phoneNumber ?? '';
          _contactEmail.text = profile.email;
        }
      } catch (_) {
        _contactName.text = session?.email.split('@').first ?? '';
      }
    });
  }

  @override
  void dispose() {
    _contactName.dispose();
    _contactPhone.dispose();
    _contactEmail.dispose();
    super.dispose();
  }

  int get _nights => _checkOutDate.difference(_checkInDate).inDays;

  double get _estimatedTotal =>
      widget.draft.roomType.basePricePerNight * _nights * _roomQuantity;

  Future<void> _pickDate({required bool checkIn}) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final firstDate =
        checkIn ? today : _checkInDate.add(const Duration(days: 1));
    final initialDate = checkIn ? _checkInDate : _checkOutDate;
    final selected = await showDatePicker(
      context: context,
      firstDate: firstDate,
      lastDate: today.add(const Duration(days: 365)),
      initialDate: initialDate.isBefore(firstDate) ? firstDate : initialDate,
    );
    if (selected == null) {
      return;
    }

    setState(() {
      if (checkIn) {
        _checkInDate = selected;
        if (!_checkOutDate.isAfter(selected)) {
          _checkOutDate = selected.add(const Duration(days: 1));
        }
      } else {
        _checkOutDate = selected;
      }
    });
  }

  Future<void> _confirmBooking() async {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState?.validate() != true) {
      return;
    }
    if (!_checkOutDate.isAfter(_checkInDate)) {
      AppErrorPresenter.showSnackBar(
        context,
        'The check-out date must be later than the check-in date.',
      );
      return;
    }
    if (_guestCount >
        widget.draft.roomType.totalGuestCapacity * _roomQuantity) {
      AppErrorPresenter.showSnackBar(
        context,
        'The selected room quantity cannot accommodate all guests.',
      );
      return;
    }

    final booking =
        await ref.read(bookingControllerProvider.notifier).createBooking(
              CreateBookingRequest(
                hotelId: widget.draft.hotel.id,
                roomTypeId: widget.draft.roomType.id,
                checkInDate: _checkInDate,
                checkOutDate: _checkOutDate,
                roomCount: _roomQuantity,
                guestCount: _guestCount,
                guestFullName: _contactName.text,
                guestPhone: _contactPhone.text,
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

    final enrichedBooking = booking.copyWith(
      hotelName: widget.draft.hotel.name,
      roomTypeName: widget.draft.roomType.name,
    );
    ref.read(customerStateProvider.notifier).addBooking(enrichedBooking);
    context.pushReplacement(
      BookingConfirmationScreen.pathFor(enrichedBooking.id),
      extra: enrichedBooking,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookingState = ref.watch(bookingControllerProvider);
    final isLoading = bookingState.isLoading;
    final maximumRooms = widget.draft.roomType.availableRoomCount;
    final maximumGuests =
        widget.draft.roomType.totalGuestCapacity * _roomQuantity;

    return SrsScreen(
      title: 'Booking Form Screen',
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SrsFieldLabel('Hotel and Room Type', required: true),
            InputDecorator(
              decoration: const InputDecoration(),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${widget.draft.hotel.name} - ${widget.draft.roomType.name}',
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _BookingDateField(
              label: 'Check-in Date',
              value: _checkInDate,
              onPressed: () => _pickDate(checkIn: true),
            ),
            const SizedBox(height: AppSpacing.lg),
            _BookingDateField(
              label: 'Check-out Date',
              value: _checkOutDate,
              onPressed: () => _pickDate(checkIn: false),
            ),
            const SizedBox(height: AppSpacing.lg),
            const SrsFieldLabel('Room Quantity', required: true),
            DropdownButtonFormField<int>(
              initialValue: _roomQuantity,
              items: [
                for (var value = 1; value <= maximumRooms; value++)
                  DropdownMenuItem(value: value, child: Text('$value')),
              ],
              onChanged: isLoading
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() {
                          _roomQuantity = value;
                          final roomCapacity =
                              widget.draft.roomType.totalGuestCapacity * value;
                          _guestCount = _guestCount.clamp(1, roomCapacity);
                        });
                      }
                    },
            ),
            const SizedBox(height: AppSpacing.lg),
            const SrsFieldLabel('Guest Count', required: true),
            DropdownButtonFormField<int>(
              key: ValueKey(maximumGuests),
              initialValue: _guestCount,
              items: [
                for (var value = 1; value <= maximumGuests; value++)
                  DropdownMenuItem(value: value, child: Text('$value')),
              ],
              onChanged: isLoading
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _guestCount = value);
                      }
                    },
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextFormField(
              controller: _contactName,
              labelText: 'Contact Name',
              externalLabel: true,
              required: true,
              textInputAction: TextInputAction.next,
              validator: AuthFormValidators.fullName,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextFormField(
              controller: _contactPhone,
              labelText: 'Contact Phone',
              externalLabel: true,
              required: true,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'Contact phone is required.';
                }
                return AuthFormValidators.phoneNumber(value);
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextFormField(
              controller: _contactEmail,
              labelText: 'Contact Email',
              externalLabel: true,
              keyboardType: TextInputType.emailAddress,
              validator: AuthFormValidators.email,
            ),
            const SizedBox(height: AppSpacing.lg),
            const SrsSectionTitle('Payment Mode'),
            RadioGroup<String>(
              groupValue: _paymentMode,
              onChanged: (value) {
                if (!isLoading && value != null) {
                  setState(() => _paymentMode = value);
                }
              },
              child: const Column(
                children: [
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    value: 'PlatformCollect',
                    title: Text('Demo Payment'),
                  ),
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    value: 'PayAtProperty',
                    title: Text('Pay at Property'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SrsPanel(
              child: Column(
                children: [
                  SrsSummaryRow(label: 'Nights', value: '$_nights'),
                  SrsSummaryRow(
                    label: 'Rate per night',
                    value: AppFormatters.money(
                      widget.draft.roomType.basePricePerNight,
                    ),
                  ),
                  SrsSummaryRow(
                    label: 'Room quantity',
                    value: '$_roomQuantity',
                  ),
                  SrsSummaryRow(
                    label: 'Price Summary',
                    value: AppFormatters.money(_estimatedTotal),
                    emphasized: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: isLoading ? null : _confirmBooking,
              child: isLoading
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Confirm Booking'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingDateField extends StatelessWidget {
  const _BookingDateField({
    required this.label,
    required this.value,
    required this.onPressed,
  });

  final String label;
  final DateTime value;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SrsFieldLabel(label, required: true),
        OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.ink,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          ),
          child: Row(
            children: [
              Expanded(child: Text(AppFormatters.displayDate(value))),
              const Icon(Icons.calendar_today_outlined),
            ],
          ),
        ),
      ],
    );
  }
}
