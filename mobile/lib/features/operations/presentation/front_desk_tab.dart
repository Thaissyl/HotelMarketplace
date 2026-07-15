import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../shared/utils/app_formatters.dart';
import '../../../shared/widgets/app_error_presenter.dart';
import '../../auth/presentation/auth_form_validators.dart';
import '../application/operations_providers.dart';
import '../domain/operations_models.dart';

class FrontDeskTab extends ConsumerWidget {
  const FrontDeskTab({super.key, required this.hotelId});

  final String hotelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Arrivals'),
              Tab(text: 'Checked In'),
              Tab(text: 'Departures'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _CheckInPanel(hotelId: hotelId),
                _WalkInPanel(hotelId: hotelId),
                _CheckOutPanel(hotelId: hotelId),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckInPanel extends ConsumerStatefulWidget {
  const _CheckInPanel({required this.hotelId});

  final String hotelId;

  @override
  ConsumerState<_CheckInPanel> createState() => _CheckInPanelState();
}

class _CheckInPanelState extends ConsumerState<_CheckInPanel> {
  final _bookingId = TextEditingController();
  final _roomTypeId = TextEditingController();
  final _guestName = TextEditingController();
  final _identity = TextEditingController();
  final Set<String> _selectedRoomIds = {};
  bool _loading = false;

  @override
  void dispose() {
    _bookingId.dispose();
    _roomTypeId.dispose();
    _guestName.dispose();
    _identity.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_bookingId.text.trim().isEmpty ||
        _guestName.text.trim().isEmpty ||
        _selectedRoomIds.isEmpty) {
      AppErrorPresenter.showSnackBar(
        context,
        'Booking id, guest name, and assigned rooms are required.',
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final result = await ref.read(operationsApiProvider).checkIn(
            hotelId: widget.hotelId,
            bookingId: _bookingId.text.trim(),
            physicalRoomIds: _selectedRoomIds.toList(growable: false),
            guestFullName: _guestName.text,
            identityDocumentNumber: _identity.text,
          );
      if (mounted) {
        _showResult(context, result);
      }
    } catch (error) {
      if (mounted) {
        await AppErrorPresenter.showBottomSheet(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _OperationList(
      children: [
        const _PanelHeader(
          icon: Icons.login_rounded,
          title: 'Arrival check-in',
          subtitle:
              'Assign available rooms and move the booking to checked-in.',
        ),
        _TextInput(controller: _bookingId, label: 'Booking ID'),
        _TextInput(
          controller: _guestName,
          label: 'Guest full name',
          validator: AuthFormValidators.fullName,
        ),
        _TextInput(
          controller: _identity,
          label: 'Identity document number',
          required: false,
        ),
        _TextInput(
          controller: _roomTypeId,
          label: 'Booked room type ID',
          required: false,
          onSubmitted: (_) => setState(() {}),
        ),
        _RoomPicker(
          hotelId: widget.hotelId,
          roomTypeId:
              _roomTypeId.text.trim().isEmpty ? null : _roomTypeId.text.trim(),
          selectedRoomIds: _selectedRoomIds,
          onChanged: () => setState(() {}),
        ),
        _PrimaryActionButton(
          label: 'Complete check-in',
          icon: Icons.key_rounded,
          loading: _loading,
          onPressed: _submit,
        ),
      ],
    );
  }
}

class _CheckOutPanel extends ConsumerStatefulWidget {
  const _CheckOutPanel({required this.hotelId});

  final String hotelId;

  @override
  ConsumerState<_CheckOutPanel> createState() => _CheckOutPanelState();
}

class _CheckOutPanelState extends ConsumerState<_CheckOutPanel> {
  final _bookingId = TextEditingController();
  final _cashAmount = TextEditingController(text: '0');
  bool _confirmCash = true;
  bool _loading = false;

  @override
  void dispose() {
    _bookingId.dispose();
    _cashAmount.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_bookingId.text.trim().isEmpty) {
      AppErrorPresenter.showSnackBar(context, 'Booking id is required.');
      return;
    }

    setState(() => _loading = true);
    try {
      final result = await ref.read(operationsApiProvider).checkOut(
            hotelId: widget.hotelId,
            bookingId: _bookingId.text.trim(),
            confirmPayAtPropertyCollection: _confirmCash,
            cashCollectedAmount: double.tryParse(_cashAmount.text) ?? 0,
          );
      if (mounted) {
        _showResult(context, result);
      }
    } catch (error) {
      if (mounted) {
        await AppErrorPresenter.showBottomSheet(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _OperationList(
      children: [
        const _PanelHeader(
          icon: Icons.logout_rounded,
          title: 'Departure checkout',
          subtitle:
              'Confirm counter payment and release rooms to housekeeping.',
        ),
        _TextInput(controller: _bookingId, label: 'Booking ID'),
        TextField(
          controller: _cashAmount,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Cash collected amount',
            prefixIcon: Icon(Icons.payments_outlined),
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _confirmCash,
          onChanged: (value) => setState(() => _confirmCash = value),
          title: const Text('Confirm pay-at-property collection'),
        ),
        _PrimaryActionButton(
          label: 'Complete checkout',
          icon: Icons.receipt_long_rounded,
          loading: _loading,
          onPressed: _submit,
        ),
      ],
    );
  }
}

class _WalkInPanel extends ConsumerStatefulWidget {
  const _WalkInPanel({required this.hotelId});

  final String hotelId;

  @override
  ConsumerState<_WalkInPanel> createState() => _WalkInPanelState();
}

class _WalkInPanelState extends ConsumerState<_WalkInPanel> {
  final _roomTypeId = TextEditingController();
  final _guestName = TextEditingController();
  final _guestPhone = TextEditingController();
  final _cash = TextEditingController(text: '0');
  final Set<String> _selectedRoomIds = {};
  DateTime _checkIn = DateTime.now();
  DateTime _checkOut = DateTime.now().add(const Duration(days: 1));
  int _guestCount = 1;
  bool _loading = false;

  @override
  void dispose() {
    _roomTypeId.dispose();
    _guestName.dispose();
    _guestPhone.dispose();
    _cash.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_roomTypeId.text.trim().isEmpty ||
        _guestName.text.trim().isEmpty ||
        _guestPhone.text.trim().length != 10 ||
        _selectedRoomIds.isEmpty) {
      AppErrorPresenter.showSnackBar(
        context,
        'Room type, room, guest name, and 10-digit phone are required.',
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final result = await ref.read(operationsApiProvider).createWalkInBooking(
            hotelId: widget.hotelId,
            roomTypeId: _roomTypeId.text.trim(),
            physicalRoomIds: _selectedRoomIds.toList(growable: false),
            checkInDate: _checkIn,
            checkOutDate: _checkOut,
            guestCount: _guestCount,
            guestFullName: _guestName.text,
            guestPhone: _guestPhone.text,
            identityDocumentNumber: '',
            cashCollectedAmount: double.tryParse(_cash.text) ?? 0,
          );
      if (mounted) {
        _showResult(context, result);
      }
    } catch (error) {
      if (mounted) {
        await AppErrorPresenter.showBottomSheet(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _pickDates() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _checkIn, end: _checkOut),
    );
    if (range != null) {
      setState(() {
        _checkIn = range.start;
        _checkOut = range.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _OperationList(
      children: [
        const _PanelHeader(
          icon: Icons.add_business_rounded,
          title: 'Walk-in booking',
          subtitle:
              'Create and check in a direct guest in one streamlined flow.',
        ),
        _TextInput(
          controller: _roomTypeId,
          label: 'Room type ID',
          onSubmitted: (_) => setState(() {}),
        ),
        OutlinedButton.icon(
          onPressed: _pickDates,
          icon: const Icon(Icons.calendar_month_rounded),
          label: Text(
            '${AppFormatters.displayDate(_checkIn)} - ${AppFormatters.displayDate(_checkOut)}',
          ),
        ),
        _GuestCountStepper(
          value: _guestCount,
          onChanged: (value) => setState(() => _guestCount = value),
        ),
        _TextInput(controller: _guestName, label: 'Guest full name'),
        _TextInput(
          controller: _guestPhone,
          label: 'Guest phone',
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
        ),
        TextField(
          controller: _cash,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Cash collected amount',
            prefixIcon: Icon(Icons.payments_outlined),
          ),
        ),
        _RoomPicker(
          hotelId: widget.hotelId,
          roomTypeId:
              _roomTypeId.text.trim().isEmpty ? null : _roomTypeId.text.trim(),
          selectedRoomIds: _selectedRoomIds,
          onChanged: () => setState(() {}),
        ),
        _PrimaryActionButton(
          label: 'Create walk-in stay',
          icon: Icons.check_circle_rounded,
          loading: _loading,
          onPressed: _submit,
        ),
      ],
    );
  }
}

class _RoomPicker extends ConsumerWidget {
  const _RoomPicker({
    required this.hotelId,
    required this.roomTypeId,
    required this.selectedRoomIds,
    required this.onChanged,
  });

  final String hotelId;
  final String? roomTypeId;
  final Set<String> selectedRoomIds;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rooms = ref.watch(
      physicalRoomsProvider(
        PhysicalRoomsRequest(hotelId: hotelId, roomTypeId: roomTypeId),
      ),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Available rooms',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            rooms.when(
              data: (items) {
                final available =
                    items.where((room) => room.isAvailable).toList();
                if (available.isEmpty) {
                  return const Text(
                    'No available room can be loaded for this scope.',
                  );
                }

                return Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final room in available)
                      FilterChip(
                        label: Text(room.roomNumber),
                        selected: selectedRoomIds.contains(room.id),
                        onSelected: (selected) {
                          if (selected) {
                            selectedRoomIds.add(room.id);
                          } else {
                            selectedRoomIds.remove(room.id);
                          }
                          onChanged();
                        },
                      ),
                  ],
                );
              },
              error: (error, stackTrace) => Text(
                'Room inventory is unavailable. Use a manager/owner account or try again later.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              loading: () => const LinearProgressIndicator(),
            ),
          ],
        ),
      ),
    );
  }
}

class _OperationList extends StatelessWidget {
  const _OperationList({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemBuilder: (context, index) => children[index],
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.md),
      itemCount: children.length,
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.brand,
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class _TextInput extends StatelessWidget {
  const _TextInput({
    required this.controller,
    required this.label,
    this.required = true,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.onSubmitted,
  });
  final TextEditingController controller;
  final String label;
  final bool required;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onSubmitted;
  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator ??
          (value) {
            if (required && (value ?? '').trim().isEmpty) {
              return '$label is required.';
            }
            return null;
          },
      onFieldSubmitted: onSubmitted,
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _GuestCountStepper extends StatelessWidget {
  const _GuestCountStepper({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text('Guests', style: Theme.of(context).textTheme.labelLarge),
        ),
        IconButton.filledTonal(
          onPressed: value <= 1 ? null : () => onChanged(value - 1),
          icon: const Icon(Icons.remove_rounded),
        ),
        SizedBox(width: 42, child: Center(child: Text('$value'))),
        IconButton.filledTonal(
          onPressed: value >= 30 ? null : () => onChanged(value + 1),
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.label,
    required this.icon,
    required this.loading,
    required this.onPressed,
  });
  final String label;
  final IconData icon;
  final bool loading;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: loading ? null : onPressed,
      icon: loading
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon),
      label: Text(label),
    );
  }
}

void _showResult(BuildContext context, FrontDeskBookingResult result) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Booking updated',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Code: ${result.bookingCode}'),
            Text('Status: ${result.status}'),
            Text('Guest: ${result.guestFullName}'),
            Text('Total: ${AppFormatters.money(result.totalAmount)}'),
            if (result.invoiceId != null) Text('Invoice: ${result.invoiceId}'),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      );
    },
  );
}
