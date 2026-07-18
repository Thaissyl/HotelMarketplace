import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../shared/utils/app_formatters.dart';
import '../../../shared/widgets/app_error_presenter.dart';
import '../../../shared/widgets/app_text_form_field.dart';
import '../application/operations_providers.dart';
import '../domain/operations_models.dart';

class FrontDeskTab extends StatefulWidget {
  const FrontDeskTab({super.key, required this.hotelId});

  final String hotelId;

  @override
  State<FrontDeskTab> createState() => _FrontDeskTabState();
}

class _FrontDeskTabState extends State<FrontDeskTab> {
  int _selectedIndex = 0;

  Widget _buildCurrentPanel() {
    return switch (_selectedIndex) {
      0 => _BookingQueuePanel(
          hotelId: widget.hotelId,
          title: 'Arrivals',
          subtitle:
              'Confirmed guests waiting for room assignment and check-in.',
          emptyMessage: 'No confirmed arrivals are waiting for check-in.',
          status: FrontDeskBookingListStatus.confirmed,
          mode: _QueueMode.checkIn,
          onCreateWalkIn: () => setState(() => _selectedIndex = 4),
        ),
      1 => _BookingQueuePanel(
          hotelId: widget.hotelId,
          title: 'Checked in',
          subtitle: 'Guests currently staying at this hotel.',
          emptyMessage: 'No guests are currently checked in.',
          status: FrontDeskBookingListStatus.checkedIn,
          mode: _QueueMode.viewStay,
        ),
      2 => _BookingQueuePanel(
          hotelId: widget.hotelId,
          title: 'Departures',
          subtitle: 'Checked-in guests ready for checkout and payment closing.',
          emptyMessage: 'No active stays are ready for checkout.',
          status: FrontDeskBookingListStatus.checkedIn,
          mode: _QueueMode.checkOut,
        ),
      3 => _BookingQueuePanel(
          hotelId: widget.hotelId,
          title: 'History',
          subtitle: 'Completed stays with checkout and invoice records.',
          emptyMessage: 'No completed checkout history is available yet.',
          status: FrontDeskBookingListStatus.checkedOut,
          mode: _QueueMode.history,
        ),
      _ => _WalkInPanel(hotelId: widget.hotelId),
    };
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FrontDeskSegmentButton(
                      label: 'Arrivals',
                      selected: _selectedIndex == 0,
                      onPressed: () => setState(() => _selectedIndex = 0),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _FrontDeskSegmentButton(
                      label: 'Checked In',
                      selected: _selectedIndex == 1,
                      onPressed: () => setState(() => _selectedIndex = 1),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _FrontDeskSegmentButton(
                      label: 'Departures',
                      selected: _selectedIndex == 2,
                      onPressed: () => setState(() => _selectedIndex = 2),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _FrontDeskSegmentButton(
                      label: 'History',
                      selected: _selectedIndex == 3,
                      onPressed: () => setState(() => _selectedIndex = 3),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _FrontDeskSegmentButton(
                      label: 'Walk-in',
                      selected: _selectedIndex == 4,
                      onPressed: () => setState(() => _selectedIndex = 4),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(child: _buildCurrentPanel()),
        ],
      ),
    );
  }
}

class _FrontDeskSegmentButton extends StatelessWidget {
  const _FrontDeskSegmentButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final child = Text(label, maxLines: 1);

    return SizedBox(
      height: 42,
      child: selected
          ? FilledButton(onPressed: onPressed, child: child)
          : OutlinedButton(onPressed: onPressed, child: child),
    );
  }
}

enum _QueueMode { checkIn, viewStay, checkOut, history }

class _BookingQueuePanel extends ConsumerWidget {
  const _BookingQueuePanel({
    required this.hotelId,
    required this.title,
    required this.subtitle,
    required this.emptyMessage,
    required this.status,
    required this.mode,
    this.onCreateWalkIn,
  });

  final String hotelId;
  final String title;
  final String subtitle;
  final String emptyMessage;
  final FrontDeskBookingListStatus status;
  final _QueueMode mode;
  final VoidCallback? onCreateWalkIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = FrontDeskBookingsRequest(hotelId: hotelId, status: status);
    final bookings = ref.watch(frontDeskBookingsProvider(request));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(frontDeskBookingsProvider(request));
      },
      child: bookings.when(
        data: (items) {
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _PanelHeader(
                  icon: mode == _QueueMode.checkIn
                      ? Icons.login_rounded
                      : mode == _QueueMode.checkOut
                          ? Icons.logout_rounded
                          : Icons.hotel_rounded,
                  title: title,
                  subtitle: subtitle,
                );
              }

              if (items.isEmpty) {
                return _EmptyQueue(
                  message: emptyMessage,
                  actionLabel: onCreateWalkIn == null ? null : 'Create walk-in',
                  onAction: onCreateWalkIn,
                );
              }

              final booking = items[index - 1];
              return _FrontDeskBookingCard(
                booking: booking,
                mode: mode,
                onViewDetails: () => _showDetailsSheet(context, ref, booking),
                onCheckIn: () => _showCheckInSheet(context, ref, booking),
                onCheckOut: () => _showCheckOutSheet(context, ref, booking),
              );
            },
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppSpacing.md),
            itemCount: items.isEmpty ? 2 : items.length + 1,
          );
        },
        error: (error, stackTrace) => ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            _PanelHeader(
              icon: Icons.error_outline_rounded,
              title: title,
              subtitle: 'Unable to load the front desk queue.',
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              AppErrorPresenter.friendlyMessage(error),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ),
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: LinearProgressIndicator(),
        ),
      ),
    );
  }

  Future<void> _showDetailsSheet(
    BuildContext context,
    WidgetRef ref,
    FrontDeskBookingSummary booking,
  ) async {
    final action = await showModalBottomSheet<_BookingDetailAction>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _BookingDetailsSheet(
        booking: booking,
        mode: mode,
      ),
    );

    if (action == _BookingDetailAction.checkIn && context.mounted) {
      await _showCheckInSheet(context, ref, booking);
    }

    if (action == _BookingDetailAction.checkOut && context.mounted) {
      await _showCheckOutSheet(context, ref, booking);
    }
  }

  Future<void> _showCheckInSheet(
    BuildContext context,
    WidgetRef ref,
    FrontDeskBookingSummary booking,
  ) async {
    final result = await showModalBottomSheet<FrontDeskBookingResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _CheckInSheet(
        hotelId: hotelId,
        booking: booking,
      ),
    );

    if (result != null) {
      ref.invalidate(
        frontDeskBookingsProvider(
          FrontDeskBookingsRequest(
            hotelId: hotelId,
            status: FrontDeskBookingListStatus.confirmed,
          ),
        ),
      );
      ref.invalidate(
        frontDeskBookingsProvider(
          FrontDeskBookingsRequest(
            hotelId: hotelId,
            status: FrontDeskBookingListStatus.checkedIn,
          ),
        ),
      );
      if (context.mounted) {
        _showResult(context, result);
      }
    }
  }

  Future<void> _showCheckOutSheet(
    BuildContext context,
    WidgetRef ref,
    FrontDeskBookingSummary booking,
  ) async {
    final result = await showModalBottomSheet<FrontDeskBookingResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _CheckOutSheet(
        hotelId: hotelId,
        booking: booking,
      ),
    );

    if (result != null) {
      ref.invalidate(
        frontDeskBookingsProvider(
          FrontDeskBookingsRequest(
            hotelId: hotelId,
            status: FrontDeskBookingListStatus.checkedIn,
          ),
        ),
      );
      if (context.mounted) {
        _showResult(context, result);
      }
    }
  }
}

class _FrontDeskBookingCard extends StatelessWidget {
  const _FrontDeskBookingCard({
    required this.booking,
    required this.mode,
    required this.onViewDetails,
    required this.onCheckIn,
    required this.onCheckOut,
  });

  final FrontDeskBookingSummary booking;
  final _QueueMode mode;
  final VoidCallback onViewDetails;
  final VoidCallback onCheckIn;
  final VoidCallback onCheckOut;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onViewDetails,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: AppColors.brand,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking.guestFullName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          '${booking.bookingCode} - ${booking.guestPhone}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  _StatusPill(label: booking.status),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _BookingDetailGrid(booking: booking),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onViewDetails,
                      icon: const Icon(Icons.visibility_rounded),
                      label: const Text('View details'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _BookingActionButton(
                      mode: mode,
                      onCheckIn: onCheckIn,
                      onCheckOut: onCheckOut,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookingActionButton extends StatelessWidget {
  const _BookingActionButton({
    required this.mode,
    required this.onCheckIn,
    required this.onCheckOut,
  });

  final _QueueMode mode;
  final VoidCallback onCheckIn;
  final VoidCallback onCheckOut;

  @override
  Widget build(BuildContext context) {
    return switch (mode) {
      _QueueMode.checkIn => FilledButton.icon(
          onPressed: onCheckIn,
          icon: const Icon(Icons.key_rounded),
          label: const Text('Check in'),
        ),
      _QueueMode.checkOut => FilledButton.icon(
          onPressed: onCheckOut,
          icon: const Icon(Icons.receipt_long_rounded),
          label: const Text('Checkout'),
        ),
      _QueueMode.viewStay => FilledButton.icon(
          onPressed: onCheckOut,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Checkout'),
        ),
      _QueueMode.history => OutlinedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.history_rounded),
          label: const Text('Done'),
        ),
    };
  }
}

class _BookingDetailGrid extends StatelessWidget {
  const _BookingDetailGrid({required this.booking});

  final FrontDeskBookingSummary booking;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        _InfoChip(
          icon: Icons.calendar_today_rounded,
          label: booking.displayStayDates,
        ),
        _InfoChip(
          icon: Icons.bed_rounded,
          label:
              '${booking.roomQuantity} x ${booking.roomTypeName.isEmpty ? 'Room type' : booking.roomTypeName}',
        ),
        _InfoChip(
          icon: Icons.meeting_room_rounded,
          label: 'Room: ${booking.displayAssignedRooms}',
        ),
        _InfoChip(
          icon: Icons.payments_outlined,
          label: AppFormatters.money(booking.totalAmount),
        ),
        _InfoChip(
          icon: Icons.schedule_rounded,
          label: '${booking.nights} night${booking.nights == 1 ? '' : 's'}',
        ),
      ],
    );
  }
}

enum _BookingDetailAction { checkIn, checkOut }

class _BookingDetailsSheet extends StatelessWidget {
  const _BookingDetailsSheet({
    required this.booking,
    required this.mode,
  });

  final FrontDeskBookingSummary booking;
  final _QueueMode mode;

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: booking.guestFullName,
      children: [
        _BookingDetailGrid(booking: booking),
        _DetailsSection(
          title: 'Guest',
          rows: [
            _DetailsRow(label: 'Full name', value: booking.guestFullName),
            _DetailsRow(label: 'Phone', value: booking.guestPhone),
            _DetailsRow(label: 'Booking code', value: booking.bookingCode),
            _DetailsRow(label: 'Status', value: booking.status),
          ],
        ),
        _DetailsSection(
          title: 'Stay',
          rows: [
            _DetailsRow(label: 'Check-in', value: booking.displayStayDates),
            _DetailsRow(
              label: 'Room type',
              value: booking.roomTypeName.isEmpty
                  ? 'Room type not available'
                  : booking.roomTypeName,
            ),
            _DetailsRow(
              label: 'Room quantity',
              value: booking.roomQuantity.toString(),
            ),
            _DetailsRow(
              label: 'Assigned rooms',
              value: booking.displayAssignedRooms,
            ),
            _DetailsRow(label: 'Nights', value: booking.nights.toString()),
          ],
        ),
        _DetailsSection(
          title: 'Payment',
          rows: [
            _DetailsRow(
              label: 'Total amount',
              value: AppFormatters.money(booking.totalAmount),
            ),
            _DetailsRow(label: 'Payment mode', value: booking.paymentMode),
            _DetailsRow(label: 'Source', value: booking.source),
            _DetailsRow(
              label: 'Invoice',
              value: booking.invoiceId == null ? 'Not generated' : 'Generated',
            ),
          ],
        ),
        if (mode == _QueueMode.checkIn)
          FilledButton.icon(
            onPressed: () =>
                Navigator.of(context).pop(_BookingDetailAction.checkIn),
            icon: const Icon(Icons.key_rounded),
            label: const Text('Assign room & check in'),
          )
        else if (mode == _QueueMode.checkOut || mode == _QueueMode.viewStay)
          FilledButton.icon(
            onPressed: () =>
                Navigator.of(context).pop(_BookingDetailAction.checkOut),
            icon: const Icon(Icons.receipt_long_rounded),
            label: const Text('Checkout guest'),
          ),
      ],
    );
  }
}

class _DetailsSection extends StatelessWidget {
  const _DetailsSection({
    required this.title,
    required this.rows,
  });

  final String title;
  final List<_DetailsRow> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            for (final row in rows) row,
          ],
        ),
      ),
    );
  }
}

class _DetailsRow extends StatelessWidget {
  const _DetailsRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckInSheet extends ConsumerStatefulWidget {
  const _CheckInSheet({
    required this.hotelId,
    required this.booking,
  });

  final String hotelId;
  final FrontDeskBookingSummary booking;

  @override
  ConsumerState<_CheckInSheet> createState() => _CheckInSheetState();
}

class _CheckInSheetState extends ConsumerState<_CheckInSheet> {
  late final TextEditingController _guestName;
  final _identity = TextEditingController();
  final Set<String> _selectedRoomIds = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _guestName = TextEditingController(text: widget.booking.guestFullName);
  }

  @override
  void dispose() {
    _guestName.dispose();
    _identity.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_guestName.text.trim().isEmpty ||
        _selectedRoomIds.length != widget.booking.roomQuantity) {
      AppErrorPresenter.showSnackBar(
        context,
        'Select ${widget.booking.roomQuantity} available room(s) and confirm guest name.',
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final result = await ref.read(operationsApiProvider).checkIn(
            hotelId: widget.hotelId,
            bookingId: widget.booking.bookingId,
            physicalRoomIds: _selectedRoomIds.toList(growable: false),
            guestFullName: _guestName.text,
            identityDocumentNumber: _identity.text,
          );

      if (mounted) {
        Navigator.of(context).pop(result);
      }
    } catch (error) {
      if (mounted) {
        AppErrorPresenter.showSnackBar(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: 'Check in ${widget.booking.guestFullName}',
      children: [
        _BookingDetailGrid(booking: widget.booking),
        AppTextFormField(
          controller: _guestName,
          labelText: 'Guest full name',
        ),
        AppTextFormField(
          controller: _identity,
          labelText: 'Identity document number',
        ),
        _RoomPicker(
          hotelId: widget.hotelId,
          roomTypeId: widget.booking.roomTypeId,
          selectedRoomIds: _selectedRoomIds,
          onChanged: () => setState(() {}),
        ),
        FilledButton.icon(
          onPressed: _loading ? null : _submit,
          icon: _loading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.login_rounded),
          label: const Text('Complete check-in'),
        ),
      ],
    );
  }
}

class _CheckOutSheet extends ConsumerStatefulWidget {
  const _CheckOutSheet({
    required this.hotelId,
    required this.booking,
  });

  final String hotelId;
  final FrontDeskBookingSummary booking;

  @override
  ConsumerState<_CheckOutSheet> createState() => _CheckOutSheetState();
}

class _CheckOutSheetState extends ConsumerState<_CheckOutSheet> {
  late final TextEditingController _cashAmount;
  bool _confirmCash = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _cashAmount = TextEditingController(
      text: widget.booking.totalAmount.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _cashAmount.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      final result = await ref.read(operationsApiProvider).checkOut(
            hotelId: widget.hotelId,
            bookingId: widget.booking.bookingId,
            confirmPayAtPropertyCollection: _confirmCash,
            cashCollectedAmount: double.tryParse(_cashAmount.text) ?? 0,
          );

      if (mounted) {
        Navigator.of(context).pop(result);
      }
    } catch (error) {
      if (mounted) {
        AppErrorPresenter.showSnackBar(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: 'Checkout ${widget.booking.guestFullName}',
      children: [
        _BookingDetailGrid(booking: widget.booking),
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
        FilledButton.icon(
          onPressed: _loading ? null : _submit,
          icon: _loading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.logout_rounded),
          label: const Text('Complete checkout'),
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
  final _guestName = TextEditingController();
  final _guestPhone = TextEditingController();
  final _cash = TextEditingController(text: '0');
  final Set<String> _selectedRoomIds = {};
  String? _selectedRoomTypeId;
  DateTime _checkIn = DateTime.now();
  DateTime _checkOut = DateTime.now().add(const Duration(days: 1));
  int _guestCount = 1;
  bool _loading = false;

  @override
  void dispose() {
    _guestName.dispose();
    _guestPhone.dispose();
    _cash.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_guestName.text.trim().isEmpty ||
        _guestPhone.text.trim().length != 10 ||
        _selectedRoomIds.isEmpty ||
        _selectedRoomTypeId == null) {
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
            roomTypeId: _selectedRoomTypeId!,
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
        ref.invalidate(
          frontDeskBookingsProvider(
            FrontDeskBookingsRequest(
              hotelId: widget.hotelId,
              status: FrontDeskBookingListStatus.checkedIn,
            ),
          ),
        );
        setState(() => _selectedRoomIds.clear());
        _showResult(context, result);
      }
    } catch (error) {
      if (mounted) {
        AppErrorPresenter.showSnackBar(context, error);
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
          subtitle: 'Create and check in a direct guest in one flow.',
        ),
        _RoomTypePicker(
          hotelId: widget.hotelId,
          selectedRoomTypeId: _selectedRoomTypeId,
          onChanged: (roomTypeId) {
            setState(() {
              _selectedRoomTypeId = roomTypeId;
              _selectedRoomIds.clear();
            });
          },
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
        AppTextFormField(controller: _guestName, labelText: 'Guest full name'),
        AppTextFormField(
          controller: _guestPhone,
          labelText: 'Guest phone',
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
          roomTypeId: _selectedRoomTypeId,
          selectedRoomIds: _selectedRoomIds,
          onChanged: () => setState(() {}),
          onRoomSelected: (room) {
            if (_selectedRoomTypeId != room.roomTypeId) {
              setState(() => _selectedRoomTypeId = room.roomTypeId);
            }
          },
        ),
        FilledButton.icon(
          onPressed: _loading ? null : _submit,
          icon: _loading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_circle_rounded),
          label: const Text('Create walk-in stay'),
        ),
      ],
    );
  }
}

class _RoomTypePicker extends ConsumerWidget {
  const _RoomTypePicker({
    required this.hotelId,
    required this.selectedRoomTypeId,
    required this.onChanged,
  });

  final String hotelId;
  final String? selectedRoomTypeId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomTypes = ref.watch(roomTypesProvider(hotelId));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: roomTypes.when(
          data: (items) {
            final activeItems = items
                .where((item) => item.status.isEmpty || item.status == 'Active')
                .toList(growable: false);

            if (activeItems.isEmpty) {
              return const Text(
                'No active room types are available for walk-in booking.',
              );
            }

            final safeValue = activeItems.any(
              (item) => item.id == selectedRoomTypeId,
            )
                ? selectedRoomTypeId
                : null;

            return DropdownButtonFormField<String>(
              initialValue: safeValue,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Room type',
                prefixIcon: Icon(Icons.bed_rounded),
              ),
              items: [
                for (final roomType in activeItems)
                  DropdownMenuItem(
                    value: roomType.id,
                    child: Text(
                      '${roomType.displayName} - ${AppFormatters.money(roomType.basePricePerNight)} - ${roomType.totalCapacity} guests',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: onChanged,
            );
          },
          error: (error, stackTrace) => _InlineError(
            message: 'Unable to load room types.',
            onRetry: () => ref.invalidate(roomTypesProvider(hotelId)),
          ),
          loading: () => const LinearProgressIndicator(),
        ),
      ),
    );
  }
}

class _RoomPicker extends ConsumerWidget {
  const _RoomPicker({
    required this.hotelId,
    required this.roomTypeId,
    required this.selectedRoomIds,
    required this.onChanged,
    this.onRoomSelected,
  });

  final String hotelId;
  final String? roomTypeId;
  final Set<String> selectedRoomIds;
  final VoidCallback onChanged;
  final ValueChanged<RoomInventoryItem>? onRoomSelected;

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
                  return const Text('No available room can be loaded.');
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
                            onRoomSelected?.call(room);
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
                'Room inventory is unavailable.',
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

class _SheetScaffold extends StatelessWidget {
  const _SheetScaffold({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            );
          }

          return children[index - 1];
        },
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppSpacing.md),
        itemCount: children.length + 1,
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

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: AppColors.success),
      ),
    );
  }
}

class _EmptyQueue extends StatelessWidget {
  const _EmptyQueue({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(AppRadii.xl),
              ),
              child: const Icon(
                Icons.inbox_rounded,
                size: 42,
                color: AppColors.mutedInk,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Pull down to refresh this list.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add_business_rounded),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            message,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry'),
        ),
      ],
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

void _showResult(BuildContext context, FrontDeskBookingResult result) {
  final invoiceText = result.invoiceId == null ? '' : ' Invoice generated.';
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          '${result.bookingCode} updated to ${result.status}.$invoiceText',
        ),
      ),
    );
}
