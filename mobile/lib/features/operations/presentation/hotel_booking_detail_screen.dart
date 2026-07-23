import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../shared/utils/app_formatters.dart';
import '../../../shared/widgets/app_error_presenter.dart';
import '../../../shared/widgets/app_text_form_field.dart';
import '../../../shared/widgets/srs_screen.dart';
import '../application/operations_providers.dart';
import '../domain/operations_models.dart';

class HotelBookingDetailScreen extends ConsumerStatefulWidget {
  const HotelBookingDetailScreen({
    super.key,
    required this.hotelId,
    required this.booking,
  });

  final String hotelId;
  final FrontDeskBookingSummary booking;

  @override
  ConsumerState<HotelBookingDetailScreen> createState() =>
      _HotelBookingDetailScreenState();
}

class _HotelBookingDetailScreenState
    extends ConsumerState<HotelBookingDetailScreen> {
  late FrontDeskBookingSummary _booking;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _booking = widget.booking;
  }

  FrontDeskBookingsRequest get _bookingsRequest =>
      FrontDeskBookingsRequest(hotelId: widget.hotelId);

  Future<void> _reload() async {
    final bookings = await ref.refresh(
      frontDeskBookingsProvider(_bookingsRequest).future,
    );
    final updated = bookings.where((item) {
      return item.bookingId == _booking.bookingId;
    }).firstOrNull;
    if (updated != null && mounted) {
      setState(() => _booking = updated);
    }
  }

  Future<void> _assignRoom() async {
    final request = PhysicalRoomsRequest(
      hotelId: widget.hotelId,
      roomTypeId: _booking.roomTypeId,
    );
    try {
      final rooms = await ref.read(physicalRoomsProvider(request).future);
      if (!mounted) {
        return;
      }
      final currentIds =
          _booking.assignedRooms.map((room) => room.physicalRoomId).toSet();
      final eligible = rooms.where((room) {
        return room.isAvailable || currentIds.contains(room.id);
      }).toList(growable: false);
      final selected = await showDialog<Set<String>>(
        context: context,
        builder: (context) => _RoomAssignmentDialog(
          rooms: eligible,
          initiallySelected: currentIds,
          requiredCount: _booking.roomQuantity,
        ),
      );
      if (selected == null || !mounted) {
        return;
      }

      await _runAction(
        () => ref.read(operationsApiProvider).assignBookingRooms(
              hotelId: widget.hotelId,
              bookingId: _booking.bookingId,
              physicalRoomIds: selected.toList(growable: false),
            ),
        successMessage: 'Room assignment updated.',
      );
    } catch (error) {
      if (mounted) {
        await AppErrorPresenter.showBottomSheet(context, error);
      }
    }
  }

  Future<void> _checkIn() async {
    if (_booking.assignedRooms.length != _booking.roomQuantity) {
      AppErrorPresenter.showSnackBar(
        context,
        'Assign all booked rooms before check-in.',
      );
      return;
    }

    final details = await showDialog<_IdentityDetails>(
      context: context,
      builder: (context) => _IdentityDialog(
        initialGuestName: _booking.guestFullName,
      ),
    );
    if (details == null || !mounted) {
      return;
    }

    await _runAction(
      () => ref.read(operationsApiProvider).checkIn(
            hotelId: widget.hotelId,
            bookingId: _booking.bookingId,
            physicalRoomIds: _booking.assignedRooms
                .map((room) => room.physicalRoomId)
                .toList(growable: false),
            guestFullName: details.guestFullName,
            identityDocumentType: details.documentType,
            identityDocumentNumber: details.documentNumber,
            identityIssuingCountry: details.issuingCountry,
          ),
      successMessage: 'Guest checked in.',
    );
  }

  Future<void> _checkOut() async {
    final collection = await showDialog<_CheckoutCollection>(
      context: context,
      builder: (context) => _CheckoutDialog(booking: _booking),
    );
    if (collection == null || !mounted) {
      return;
    }

    await _runAction(
      () => ref.read(operationsApiProvider).checkOut(
            hotelId: widget.hotelId,
            bookingId: _booking.bookingId,
            confirmPayAtPropertyCollection: collection.confirmed,
            cashCollectedAmount: collection.amount,
            collectionMethod: collection.method,
            collectionReference: collection.reference,
            collectionNote: collection.note,
          ),
      successMessage: 'Checkout completed.',
    );
  }

  Future<void> _markNoShow() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark booking as no-show'),
        content: AppTextFormField(
          controller: controller,
          labelText: 'Reason',
          hintText: 'Enter an operational reason',
          externalLabel: true,
          maxLines: 3,
          inputFormatters: [LengthLimitingTextInputFormatter(500)],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty) {
                AppErrorPresenter.showSnackBar(
                  context,
                  'A no-show reason is required.',
                );
                return;
              }
              Navigator.of(context).pop(value);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || !mounted) {
      return;
    }

    await _runAction(
      () => ref.read(operationsApiProvider).markBookingNoShow(
            hotelId: widget.hotelId,
            bookingId: _booking.bookingId,
            reason: reason,
          ),
      successMessage: 'Booking marked as no-show.',
    );
  }

  Future<void> _runAction(
    Future<FrontDeskBookingResult> Function() action, {
    required String successMessage,
  }) async {
    setState(() => _processing = true);
    try {
      await action();
      await _reload();
      if (mounted) {
        AppErrorPresenter.showSnackBar(context, successMessage);
      }
    } catch (error) {
      if (mounted) {
        await AppErrorPresenter.showBottomSheet(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  void _explainPaymentCollection() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Record Payment'),
        content: const Text(
          'In this MVP, pay-at-property collection is recorded atomically '
          'during Checkout. Use Checkout to enter the collected amount and '
          'receipt reference.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canAssign = _booking.status == 'Confirmed';
    final canCheckIn = _booking.status == 'Confirmed';
    final canCheckout = _booking.status == 'CheckedIn';
    final canMarkNoShow = _booking.status == 'Confirmed';
    final balance =
        _booking.paymentMode == 'PayAtProperty' ? _booking.totalAmount : 0.0;

    return SrsScreen(
      title: 'Booking Detail',
      actions: [
        IconButton(
          tooltip: 'Refresh booking',
          onPressed: _processing ? null : _reload,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DetailPanel(
            title: 'Booking Summary',
            rows: [
              _DetailRowData(
                icon: Icons.sell_outlined,
                label: 'Booking Code',
                value: _booking.bookingCode,
              ),
              _DetailRowData(
                icon: Icons.person_outline_rounded,
                label: 'Guest',
                value: _booking.guestFullName,
              ),
              _DetailRowData(
                icon: Icons.bed_rounded,
                label: 'Room Type',
                value: '${_booking.roomTypeName} x ${_booking.roomQuantity}',
              ),
              _DetailRowData(
                icon: Icons.calendar_month_outlined,
                label: 'Dates',
                value: _booking.displayStayDates,
              ),
              _DetailRowData(
                icon: Icons.info_outline_rounded,
                label: 'Status',
                value: _readableStatus(_booking.status),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _DetailPanel(
            title: 'Payment Summary',
            rows: [
              _DetailRowData(
                icon: Icons.credit_card_outlined,
                label: 'Payment Mode',
                value: _readableStatus(_booking.paymentMode),
              ),
              _DetailRowData(
                icon: Icons.paid_outlined,
                label: 'Collection / Balance',
                value: AppFormatters.money(balance),
              ),
              _DetailRowData(
                icon: Icons.receipt_long_outlined,
                label: 'Booking Total',
                value: AppFormatters.money(_booking.totalAmount),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _DetailPanel(
            title: 'Room Assignment',
            rows: [
              _DetailRowData(
                icon: Icons.bed_outlined,
                label: 'Assigned Physical Room',
                value: _booking.displayAssignedRooms,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SrsPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SrsSectionTitle('Allowed Actions'),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            !_processing && canAssign ? _assignRoom : null,
                        icon: const Icon(Icons.person_add_alt_outlined),
                        label: const Text('Assign Room'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: !_processing && canCheckIn ? _checkIn : null,
                        icon: const Icon(Icons.login_rounded),
                        label: const Text('Check In'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            !_processing && canCheckout ? _checkOut : null,
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('Checkout'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            !_processing && canMarkNoShow ? _markNoShow : null,
                        icon: const Icon(Icons.person_off_outlined),
                        label: const Text('No-show'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: _processing ? null : _explainPaymentCollection,
                  icon: const Icon(Icons.paid_outlined),
                  label: const Text('Record Payment'),
                ),
                if (_processing) ...[
                  const SizedBox(height: AppSpacing.md),
                  const LinearProgressIndicator(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailPanel extends StatelessWidget {
  const _DetailPanel({required this.title, required this.rows});

  final String title;
  final List<_DetailRowData> rows;

  @override
  Widget build(BuildContext context) {
    return SrsPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  SizedBox(width: 42, child: Icon(row.icon)),
                  const SizedBox(width: AppSpacing.xs),
                  SizedBox(
                    width: 128,
                    child: Text(
                      row.label,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  const Text(':'),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      row.value.trim().isEmpty ? 'Not available' : row.value,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
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

class _DetailRowData {
  const _DetailRowData({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

class _RoomAssignmentDialog extends StatefulWidget {
  const _RoomAssignmentDialog({
    required this.rooms,
    required this.initiallySelected,
    required this.requiredCount,
  });

  final List<RoomInventoryItem> rooms;
  final Set<String> initiallySelected;
  final int requiredCount;

  @override
  State<_RoomAssignmentDialog> createState() => _RoomAssignmentDialogState();
}

class _RoomAssignmentDialogState extends State<_RoomAssignmentDialog> {
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = {...widget.initiallySelected};
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Assign Physical Rooms'),
      content: SizedBox(
        width: double.maxFinite,
        child: widget.rooms.isEmpty
            ? const Text('No available rooms match this room type.')
            : ListView(
                shrinkWrap: true,
                children: [
                  Text(
                    'Select ${widget.requiredCount} room'
                    '${widget.requiredCount == 1 ? '' : 's'}.',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  for (final room in widget.rooms)
                    CheckboxListTile(
                      value: _selected.contains(room.id),
                      title: Text('Room ${room.roomNumber}'),
                      subtitle: Text(
                        'Floor ${room.floor?.trim().isNotEmpty == true ? room.floor : '-'}',
                      ),
                      onChanged: (selected) {
                        setState(() {
                          if (selected == true) {
                            if (_selected.length < widget.requiredCount) {
                              _selected.add(room.id);
                            }
                          } else {
                            _selected.remove(room.id);
                          }
                        });
                      },
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selected.length == widget.requiredCount
              ? () => Navigator.of(context).pop(_selected)
              : null,
          child: const Text('Assign'),
        ),
      ],
    );
  }
}

class _IdentityDialog extends StatefulWidget {
  const _IdentityDialog({required this.initialGuestName});

  final String initialGuestName;

  @override
  State<_IdentityDialog> createState() => _IdentityDialogState();
}

class _IdentityDialogState extends State<_IdentityDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _guestName;
  final _documentNumber = TextEditingController();
  final _country = TextEditingController();
  String _documentType = 'NationalId';

  @override
  void initState() {
    super.initState();
    _guestName = TextEditingController(text: widget.initialGuestName);
  }

  @override
  void dispose() {
    _guestName.dispose();
    _documentNumber.dispose();
    _country.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Check In Guest'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextFormField(
                controller: _guestName,
                labelText: 'Guest Full Name',
                externalLabel: true,
                validator: _required,
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: _documentType,
                decoration:
                    const InputDecoration(labelText: 'Identity Document'),
                items: const [
                  DropdownMenuItem(
                    value: 'NationalId',
                    child: Text('National ID'),
                  ),
                  DropdownMenuItem(value: 'Passport', child: Text('Passport')),
                  DropdownMenuItem(
                    value: 'DriverLicense',
                    child: Text('Driver License'),
                  ),
                ],
                onChanged: (value) {
                  setState(() => _documentType = value ?? 'NationalId');
                },
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextFormField(
                controller: _documentNumber,
                labelText: 'Document Number',
                externalLabel: true,
                validator: _required,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextFormField(
                controller: _country,
                labelText: 'Issuing Country',
                hintText: 'VN',
                externalLabel: true,
                inputFormatters: [LengthLimitingTextInputFormatter(3)],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState?.validate() != true) {
              return;
            }
            Navigator.of(context).pop(
              _IdentityDetails(
                guestFullName: _guestName.text.trim(),
                documentType: _documentType,
                documentNumber: _documentNumber.text.trim(),
                issuingCountry: _country.text.trim(),
              ),
            );
          },
          child: const Text('Check In'),
        ),
      ],
    );
  }
}

class _CheckoutDialog extends StatefulWidget {
  const _CheckoutDialog({required this.booking});

  final FrontDeskBookingSummary booking;

  @override
  State<_CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<_CheckoutDialog> {
  late final TextEditingController _amount;
  final _reference = TextEditingController();
  final _note = TextEditingController();
  String _method = 'Cash';
  bool _confirmed = false;

  bool get _requiresCollection => widget.booking.paymentMode == 'PayAtProperty';

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(
      text: _requiresCollection
          ? widget.booking.totalAmount.toStringAsFixed(0)
          : '0',
    );
    _confirmed = !_requiresCollection;
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Checkout & Collection'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextFormField(
              controller: _amount,
              labelText: 'Amount Collected',
              externalLabel: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _method,
              decoration: const InputDecoration(labelText: 'Method'),
              items: const [
                DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                DropdownMenuItem(
                  value: 'BankTransfer',
                  child: Text('Bank Transfer'),
                ),
                DropdownMenuItem(value: 'Card', child: Text('Card')),
              ],
              onChanged: (value) => setState(() => _method = value ?? 'Cash'),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextFormField(
              controller: _reference,
              labelText: 'Receipt Reference',
              externalLabel: true,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextFormField(
              controller: _note,
              labelText: 'Collection Note',
              externalLabel: true,
              maxLines: 2,
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _confirmed,
              title: const Text('Collection confirmed'),
              onChanged: _requiresCollection
                  ? (value) => setState(() => _confirmed = value == true)
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: !_confirmed
              ? null
              : () {
                  final amount = double.tryParse(_amount.text.trim());
                  if (amount == null || amount < 0) {
                    AppErrorPresenter.showSnackBar(
                      context,
                      'Enter a valid collected amount.',
                    );
                    return;
                  }
                  Navigator.of(context).pop(
                    _CheckoutCollection(
                      confirmed: _confirmed,
                      amount: amount,
                      method: _method,
                      reference: _reference.text,
                      note: _note.text,
                    ),
                  );
                },
          child: const Text('Complete Checkout'),
        ),
      ],
    );
  }
}

class _IdentityDetails {
  const _IdentityDetails({
    required this.guestFullName,
    required this.documentType,
    required this.documentNumber,
    required this.issuingCountry,
  });

  final String guestFullName;
  final String documentType;
  final String documentNumber;
  final String issuingCountry;
}

class _CheckoutCollection {
  const _CheckoutCollection({
    required this.confirmed,
    required this.amount,
    required this.method,
    required this.reference,
    required this.note,
  });

  final bool confirmed;
  final double amount;
  final String method;
  final String reference;
  final String note;
}

String? _required(String? value) {
  return value == null || value.trim().isEmpty
      ? 'This field is required.'
      : null;
}

String _readableStatus(String value) {
  return value.replaceAllMapped(
    RegExp(r'(?<=[a-z])(?=[A-Z])'),
    (match) => ' ',
  );
}
