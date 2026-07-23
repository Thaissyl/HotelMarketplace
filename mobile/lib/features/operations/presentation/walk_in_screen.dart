import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../shared/utils/app_formatters.dart';
import '../../../shared/widgets/app_error_presenter.dart';
import '../application/operations_providers.dart';
import '../domain/operations_models.dart';
import 'front_desk_components.dart';

class WalkInBookingScreen extends ConsumerStatefulWidget {
  const WalkInBookingScreen({super.key, required this.hotelId});

  final String hotelId;

  @override
  ConsumerState<WalkInBookingScreen> createState() =>
      _WalkInBookingScreenState();
}

class _WalkInBookingScreenState extends ConsumerState<WalkInBookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _guestName = TextEditingController();
  final _phone = TextEditingController();
  final _identityNumber = TextEditingController();
  DateTime _checkIn = DateUtils.dateOnly(DateTime.now());
  DateTime _checkOut =
      DateUtils.dateOnly(DateTime.now()).add(const Duration(days: 1));
  String _identityType = 'NationalId';
  String? _roomTypeId;
  int _roomQuantity = 1;
  String _paymentMode = 'Cash';
  bool _submitting = false;

  @override
  void dispose() {
    _guestName.dispose();
    _phone.dispose();
    _identityNumber.dispose();
    super.dispose();
  }

  Future<void> _pickDates() async {
    final range = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _checkIn, end: _checkOut),
      firstDate: DateUtils.dateOnly(DateTime.now()),
      lastDate: DateUtils.dateOnly(
        DateTime.now().add(const Duration(days: 365)),
      ),
    );
    if (range != null && mounted) {
      setState(() {
        _checkIn = DateUtils.dateOnly(range.start);
        _checkOut = DateUtils.dateOnly(range.end);
      });
    }
  }

  Future<void> _submit(List<RoomTypeInventoryItem> roomTypes) async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_roomTypeId == null) {
      AppErrorPresenter.showSnackBar(context, 'Select a room type.');
      return;
    }
    if (_paymentMode != 'Cash') {
      AppErrorPresenter.showSnackBar(
        context,
        'The current walk-in API supports cash collection only.',
      );
      return;
    }
    if (DateUtils.isSameDay(_checkIn, DateTime.now()) &&
        _identityNumber.text.trim().isEmpty) {
      AppErrorPresenter.showSnackBar(
        context,
        'Enter the identity document number for immediate check-in.',
      );
      return;
    }

    RoomTypeInventoryItem? roomType;
    for (final item in roomTypes) {
      if (item.id == _roomTypeId) {
        roomType = item;
        break;
      }
    }
    if (roomType == null) {
      AppErrorPresenter.showSnackBar(
        context,
        'The selected room type is no longer available.',
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final assignNow = DateUtils.isSameDay(_checkIn, DateTime.now());
      final physicalRoomIds = <String>[];
      if (assignNow) {
        final rooms = await ref.read(
          physicalRoomsProvider(
            PhysicalRoomsRequest(
              hotelId: widget.hotelId,
              roomTypeId: _roomTypeId,
            ),
          ).future,
        );
        final available = rooms
            .where((room) => room.isAvailable)
            .take(_roomQuantity)
            .toList(growable: false);
        if (available.length != _roomQuantity) {
          throw StateError(
            'Not enough available physical rooms for immediate check-in.',
          );
        }
        physicalRoomIds.addAll(available.map((room) => room.id));
      }

      final nights = _checkOut.difference(_checkIn).inDays;
      final totalAmount = roomType.basePricePerNight * _roomQuantity * nights;
      final result = await ref.read(operationsApiProvider).createWalkInBooking(
            hotelId: widget.hotelId,
            roomTypeId: roomType.id,
            roomCount: _roomQuantity,
            physicalRoomIds: physicalRoomIds,
            checkInDate: _checkIn,
            checkOutDate: _checkOut,
            guestCount: _roomQuantity,
            guestFullName: _guestName.text,
            guestPhone: _phone.text,
            identityDocumentType: assignNow ? _identityType : '',
            identityDocumentNumber: assignNow ? _identityNumber.text : '',
            cashCollectedAmount: totalAmount,
          );
      if (mounted) {
        Navigator.of(context).pop(result);
      }
    } catch (error) {
      if (mounted) {
        await AppErrorPresenter.showBottomSheet(
          context,
          error,
          title: 'Walk-in booking not created',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomTypesState = ref.watch(roomTypesProvider(widget.hotelId));

    return FrontDeskRouteScaffold(
      title: 'Walk-in Booking Screen',
      body: roomTypesState.when(
        loading: () => const FrontDeskLoadingState(),
        error: (error, stackTrace) => FrontDeskErrorState(
          error: error,
          title: 'Unable to load room types',
          onRetry: () => ref.invalidate(roomTypesProvider(widget.hotelId)),
        ),
        data: (roomTypes) {
          final activeRoomTypes = roomTypes
              .where((item) => item.status.isEmpty || item.status == 'Active')
              .toList(growable: false);
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                const FrontDeskFieldLabel('Guest Name'),
                TextFormField(
                  controller: _guestName,
                  enabled: !_submitting,
                  decoration: const InputDecoration(
                    hintText: 'Enter guest full name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.length < 2 || text.length > 200) {
                      return 'Enter the guest full name.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                const FrontDeskFieldLabel('Contact Phone'),
                TextFormField(
                  controller: _phone,
                  enabled: !_submitting,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: const InputDecoration(
                    hintText: 'Enter contact phone number',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (value) {
                    return RegExp(r'^\d{10}$').hasMatch(value?.trim() ?? '')
                        ? null
                        : 'Phone number must contain 10 digits.';
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                const FrontDeskFieldLabel('Identity Document'),
                DropdownButtonFormField<String>(
                  initialValue: _identityType,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'NationalId',
                      child: Text('National ID'),
                    ),
                    DropdownMenuItem(
                      value: 'Passport',
                      child: Text('Passport'),
                    ),
                    DropdownMenuItem(
                      value: 'DriverLicense',
                      child: Text('Driver License'),
                    ),
                  ],
                  onChanged: _submitting
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _identityType = value);
                          }
                        },
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _identityNumber,
                  enabled: !_submitting,
                  decoration: const InputDecoration(
                    labelText: 'Identity Document Number',
                    prefixIcon: Icon(Icons.credit_card_outlined),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isNotEmpty && text.length > 64) {
                      return 'Identity document number is too long.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                const FrontDeskFieldLabel('Dates'),
                _DateRangeField(
                  checkIn: _checkIn,
                  checkOut: _checkOut,
                  onTap: _submitting ? null : _pickDates,
                ),
                const SizedBox(height: AppSpacing.lg),
                const FrontDeskFieldLabel('Room Type'),
                DropdownButtonFormField<String>(
                  initialValue: activeRoomTypes.any(
                    (item) => item.id == _roomTypeId,
                  )
                      ? _roomTypeId
                      : null,
                  decoration: const InputDecoration(
                    hintText: 'Select room type',
                    prefixIcon: Icon(Icons.bed_outlined),
                  ),
                  isExpanded: true,
                  items: [
                    for (final roomType in activeRoomTypes)
                      DropdownMenuItem(
                        value: roomType.id,
                        child: Text(
                          '${roomType.displayName} - '
                          '${AppFormatters.money(roomType.basePricePerNight)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _submitting
                      ? null
                      : (value) => setState(() => _roomTypeId = value),
                ),
                const SizedBox(height: AppSpacing.lg),
                const FrontDeskFieldLabel('Room Quantity'),
                _RoomQuantityStepper(
                  value: _roomQuantity,
                  onChanged: _submitting
                      ? null
                      : (value) => setState(() => _roomQuantity = value),
                ),
                const SizedBox(height: AppSpacing.lg),
                const FrontDeskFieldLabel('Payment Mode'),
                _PaymentModeSelector(
                  value: _paymentMode,
                  onChanged: _submitting
                      ? null
                      : (value) {
                          if (value != 'Cash') {
                            AppErrorPresenter.showSnackBar(
                              context,
                              'Only Cash is supported for walk-in bookings.',
                            );
                            return;
                          }
                          setState(() => _paymentMode = value);
                        },
                ),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submitting || activeRoomTypes.isEmpty
                        ? null
                        : () => _submit(activeRoomTypes),
                    child: _submitting
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Create Booking Button'),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DateRangeField extends StatelessWidget {
  const _DateRangeField({
    required this.checkIn,
    required this.checkOut,
    required this.onTap,
  });

  final DateTime checkIn;
  final DateTime checkOut;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: const InputDecoration(),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_outlined),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Check-in'),
                  Text(
                    AppFormatters.displayDate(checkIn),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Check-out'),
                  Text(
                    AppFormatters.displayDate(checkOut),
                    style: Theme.of(context).textTheme.titleSmall,
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Icon(Icons.calendar_month_outlined),
          ],
        ),
      ),
    );
  }
}

class _RoomQuantityStepper extends StatelessWidget {
  const _RoomQuantityStepper({
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          _StepperAction(
            icon: Icons.remove,
            onTap: value > 1 && onChanged != null
                ? () => onChanged!(value - 1)
                : null,
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Center(
              child: Text(
                '$value',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          _StepperAction(
            icon: Icons.add,
            onTap: value < 10 && onChanged != null
                ? () => onChanged!(value + 1)
                : null,
          ),
        ],
      ),
    );
  }
}

class _StepperAction extends StatelessWidget {
  const _StepperAction({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: double.infinity,
      child: IconButton(onPressed: onTap, icon: Icon(icon)),
    );
  }
}

class _PaymentModeSelector extends StatelessWidget {
  const _PaymentModeSelector({
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String>? onChanged;

  static const _modes = [
    ('Cash', Icons.account_balance_wallet_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          for (var index = 0; index < _modes.length; index++) ...[
            if (index > 0) const VerticalDivider(width: 1),
            Expanded(
              child: InkWell(
                onTap: onChanged == null
                    ? null
                    : () => onChanged!(_modes[index].$1),
                child: ColoredBox(
                  color: value == _modes[index].$1
                      ? Theme.of(context).colorScheme.surfaceContainerHighest
                      : Colors.transparent,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_modes[index].$2),
                        const SizedBox(height: AppSpacing.xxs),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(_modes[index].$1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
