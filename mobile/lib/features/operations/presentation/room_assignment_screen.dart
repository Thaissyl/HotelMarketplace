import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../shared/widgets/app_error_presenter.dart';
import '../application/operations_providers.dart';
import '../domain/operations_models.dart';
import 'check_in_screen.dart';
import 'front_desk_components.dart';

class RoomAssignmentScreen extends ConsumerStatefulWidget {
  const RoomAssignmentScreen({
    super.key,
    required this.hotelId,
    required this.booking,
  });

  final String hotelId;
  final FrontDeskBookingSummary booking;

  @override
  ConsumerState<RoomAssignmentScreen> createState() =>
      _RoomAssignmentScreenState();
}

class _RoomAssignmentScreenState extends ConsumerState<RoomAssignmentScreen> {
  late final Set<String> _originalRoomIds;
  late final Set<String> _selectedRoomIds;
  String _conflictMessage = 'No conflict';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _originalRoomIds =
        widget.booking.assignedRooms.map((room) => room.physicalRoomId).toSet();
    _selectedRoomIds = {..._originalRoomIds};
  }

  Future<void> _assignOrContinue(List<RoomInventoryItem> rooms) async {
    if (_selectedRoomIds.length != widget.booking.roomQuantity) {
      setState(() {
        _conflictMessage =
            'Select exactly ${widget.booking.roomQuantity} room(s).';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _conflictMessage = 'Checking room assignment';
    });
    try {
      FrontDeskBookingResult? assignmentResult;
      if (!_hasSameSelection()) {
        assignmentResult =
            await ref.read(operationsApiProvider).assignBookingRooms(
                  hotelId: widget.hotelId,
                  bookingId: widget.booking.bookingId,
                  physicalRoomIds: _selectedRoomIds.toList(growable: false),
                );
      }

      if (!mounted) {
        return;
      }

      setState(() => _conflictMessage = 'No conflict');
      if (!DateUtils.isSameDay(widget.booking.checkInDate, DateTime.now())) {
        if (assignmentResult == null) {
          AppErrorPresenter.showSnackBar(
            context,
            'This room assignment is already current.',
          );
          Navigator.of(context).pop();
        } else {
          Navigator.of(context).pop(assignmentResult);
        }
        return;
      }

      final roomNumbers = <String>[
        for (final roomId in _selectedRoomIds)
          _roomNumberFor(roomId, rooms, assignmentResult),
      ];
      final checkInResult =
          await Navigator.of(context).push<FrontDeskBookingResult>(
        MaterialPageRoute(
          builder: (context) => CheckInScreen(
            hotelId: widget.hotelId,
            booking: widget.booking,
            physicalRoomIds: _selectedRoomIds.toList(growable: false),
            roomNumbers: roomNumbers,
          ),
        ),
      );
      if (checkInResult != null && mounted) {
        Navigator.of(context).pop(checkInResult);
      } else if (assignmentResult != null && mounted) {
        Navigator.of(context).pop(assignmentResult);
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _conflictMessage = AppErrorPresenter.friendlyMessage(error),
        );
        await AppErrorPresenter.showBottomSheet(
          context,
          error,
          title: 'Room assignment not saved',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  bool _hasSameSelection() {
    return _selectedRoomIds.length == _originalRoomIds.length &&
        _selectedRoomIds.every(_originalRoomIds.contains);
  }

  String _roomNumberFor(
    String roomId,
    List<RoomInventoryItem> rooms,
    FrontDeskBookingResult? result,
  ) {
    for (final room in rooms) {
      if (room.id == roomId) {
        return room.roomNumber;
      }
    }
    for (final room in result?.assignedRooms ?? const <AssignedRoomResult>[]) {
      if (room.physicalRoomId == roomId) {
        return room.roomNumber;
      }
    }
    for (final room in widget.booking.assignedRooms) {
      if (room.physicalRoomId == roomId) {
        return room.roomNumber;
      }
    }
    return 'Assigned room';
  }

  @override
  Widget build(BuildContext context) {
    final request = PhysicalRoomsRequest(
      hotelId: widget.hotelId,
      roomTypeId: widget.booking.roomTypeId,
    );
    final roomState = ref.watch(physicalRoomsProvider(request));

    return FrontDeskRouteScaffold(
      title: 'Room Assignment Board',
      body: roomState.when(
        loading: () => const FrontDeskLoadingState(),
        error: (error, stackTrace) => FrontDeskErrorState(
          error: error,
          title: 'Unable to load available rooms',
          onRetry: () => ref.invalidate(physicalRoomsProvider(request)),
        ),
        data: (rooms) {
          final selectableRooms = rooms
              .where(
                (room) =>
                    room.isAvailable || _selectedRoomIds.contains(room.id),
              )
              .toList(growable: false)
            ..sort(
              (left, right) => left.roomNumber.compareTo(right.roomNumber),
            );
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _BookingRequirement(booking: widget.booking),
              const SizedBox(height: AppSpacing.md),
              _AvailableRoomList(
                rooms: selectableRooms,
                selectedRoomIds: _selectedRoomIds,
                maximumSelections: widget.booking.roomQuantity,
                onChanged: () => setState(() {
                  _conflictMessage = 'No conflict';
                }),
              ),
              const SizedBox(height: AppSpacing.md),
              _AssignedRoomList(
                booking: widget.booking,
                rooms: rooms,
                selectedRoomIds: _selectedRoomIds,
                onSubmit: _submitting ? null : () => _assignOrContinue(rooms),
                submitting: _submitting,
              ),
              const SizedBox(height: AppSpacing.md),
              _ConflictMessage(message: _conflictMessage),
              const SizedBox(height: AppSpacing.lg),
            ],
          );
        },
      ),
    );
  }
}

class _BookingRequirement extends StatelessWidget {
  const _BookingRequirement({required this.booking});

  final FrontDeskBookingSummary booking;

  @override
  Widget build(BuildContext context) {
    return FrontDeskPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FrontDeskSectionTitle('Booking Requirement'),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth - AppSpacing.md) / 2;
              return Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.lg,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: _RequirementItem(
                      icon: Icons.receipt_long_outlined,
                      label: 'Booking Code',
                      value: booking.bookingCode,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _RequirementItem(
                      icon: Icons.calendar_month_outlined,
                      label: 'Dates',
                      value: booking.displayStayDates,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _RequirementItem(
                      icon: Icons.bed_outlined,
                      label: 'Room Type',
                      value: booking.roomTypeName.isEmpty
                          ? 'Room type unavailable'
                          : booking.roomTypeName,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _RequirementItem(
                      icon: Icons.people_outline,
                      label: 'Guests',
                      value: booking.guestCount > 0
                          ? '${booking.guestCount} guest${booking.guestCount == 1 ? '' : 's'}'
                          : 'Guest count unavailable',
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RequirementItem extends StatelessWidget {
  const _RequirementItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 28),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                value,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AvailableRoomList extends StatelessWidget {
  const _AvailableRoomList({
    required this.rooms,
    required this.selectedRoomIds,
    required this.maximumSelections,
    required this.onChanged,
  });

  final List<RoomInventoryItem> rooms;
  final Set<String> selectedRoomIds;
  final int maximumSelections;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return FrontDeskPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FrontDeskSectionTitle('Available Room List'),
          const SizedBox(height: AppSpacing.xxs),
          const Text('Select a room to assign'),
          const SizedBox(height: AppSpacing.md),
          if (rooms.isEmpty)
            const Text('No available physical room matches this room type.')
          else
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var index = 0; index < rooms.length; index++) ...[
                    if (index > 0) const Divider(height: 1),
                    _AvailableRoomRow(
                      room: rooms[index],
                      selected: selectedRoomIds.contains(rooms[index].id),
                      onTap: () {
                        final room = rooms[index];
                        if (selectedRoomIds.contains(room.id)) {
                          selectedRoomIds.remove(room.id);
                        } else if (selectedRoomIds.length < maximumSelections) {
                          selectedRoomIds.add(room.id);
                        } else if (maximumSelections == 1) {
                          selectedRoomIds
                            ..clear()
                            ..add(room.id);
                        }
                        onChanged();
                      },
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AvailableRoomRow extends StatelessWidget {
  const _AvailableRoomRow({
    required this.room,
    required this.selected,
    required this.onTap,
  });

  final RoomInventoryItem room;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.onSurface,
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: selected
                  ? Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: AppSpacing.md),
            const Icon(Icons.bed_outlined, size: 28),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.roomNumber,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    room.floor?.isNotEmpty == true
                        ? 'Floor ${room.floor}'
                        : 'Floor not specified',
                  ),
                ],
              ),
            ),
            const FrontDeskStatusTag('Available'),
          ],
        ),
      ),
    );
  }
}

class _AssignedRoomList extends StatelessWidget {
  const _AssignedRoomList({
    required this.booking,
    required this.rooms,
    required this.selectedRoomIds,
    required this.onSubmit,
    required this.submitting,
  });

  final FrontDeskBookingSummary booking;
  final List<RoomInventoryItem> rooms;
  final Set<String> selectedRoomIds;
  final VoidCallback? onSubmit;
  final bool submitting;

  @override
  Widget build(BuildContext context) {
    final selectedRooms = rooms
        .where((room) => selectedRoomIds.contains(room.id))
        .toList(growable: false);

    return FrontDeskPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FrontDeskSectionTitle('Assigned Room List'),
          const SizedBox(height: AppSpacing.xxs),
          const Text('Currently assigned room(s)'),
          const SizedBox(height: AppSpacing.md),
          if (selectedRooms.isEmpty)
            const Text('No physical room is currently selected.')
          else
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  for (var index = 0;
                      index < selectedRooms.length;
                      index++) ...[
                    if (index > 0) const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: [
                          const Icon(Icons.bed_outlined, size: 28),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selectedRooms[index].roomNumber,
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                Text(
                                  booking.roomTypeName.isEmpty
                                      ? 'Room type unavailable'
                                      : booking.roomTypeName,
                                ),
                                Text(
                                  selectedRooms[index].floor?.isNotEmpty == true
                                      ? 'Floor ${selectedRooms[index].floor}'
                                      : 'Floor not specified',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Flexible(
                            child: Text(
                              booking.displayStayDates,
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onSubmit,
              icon: submitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              label: const Text('Assign / Change'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConflictMessage extends StatelessWidget {
  const _ConflictMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final hasConflict =
        message != 'No conflict' && message != 'Checking room assignment';
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(
          color: hasConflict
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.outline,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            hasConflict ? Icons.warning_amber_outlined : Icons.info_outline,
            size: 32,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Conflict Message Area',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(message),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
