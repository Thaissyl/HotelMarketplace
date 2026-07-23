import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../shared/widgets/srs_screen.dart';
import '../application/operations_providers.dart';
import '../domain/operations_models.dart';

class RoomStatusBoard extends ConsumerStatefulWidget {
  const RoomStatusBoard({super.key, required this.hotelId});

  final String hotelId;

  @override
  ConsumerState<RoomStatusBoard> createState() => _RoomStatusBoardState();
}

class _RoomStatusBoardState extends ConsumerState<RoomStatusBoard> {
  String? _roomTypeId;
  RoomInventoryItem? _selectedRoom;

  PhysicalRoomsRequest get _roomRequest =>
      PhysicalRoomsRequest(hotelId: widget.hotelId);

  Future<void> _refresh() async {
    ref.invalidate(physicalRoomsProvider(_roomRequest));
    ref.invalidate(roomTypesProvider(widget.hotelId));
    ref.invalidate(workingHotelsProvider);
    await Future.wait([
      ref.read(physicalRoomsProvider(_roomRequest).future),
      ref.read(roomTypesProvider(widget.hotelId).future),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final rooms = ref.watch(physicalRoomsProvider(_roomRequest));
    final roomTypes = ref.watch(roomTypesProvider(widget.hotelId));
    final hotels = ref.watch(workingHotelsProvider);

    return SrsScreen(
      title: 'Room Status Board',
      scrollable: false,
      padding: EdgeInsets.zero,
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: rooms.when(
          data: (roomItems) => roomTypes.when(
            data: (typeItems) {
              final typeNames = {
                for (final roomType in typeItems)
                  roomType.id: roomType.displayName,
              };
              final visibleRooms = roomItems
                  .where(
                    (room) =>
                        _roomTypeId == null || room.roomTypeId == _roomTypeId,
                  )
                  .toList(growable: false)
                ..sort(
                  (left, right) => left.roomNumber.compareTo(right.roomNumber),
                );
              final selected = _selectedRoom != null &&
                      visibleRooms.any((room) => room.id == _selectedRoom!.id)
                  ? _selectedRoom
                  : visibleRooms.firstOrNull;

              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.xl),
                children: [
                  const SrsFieldLabel('Hotel/Room Type Filters'),
                  Row(
                    children: [
                      Expanded(
                        child: hotels.when(
                          data: (items) {
                            final hotel = items
                                .where((item) => item.id == widget.hotelId)
                                .firstOrNull;
                            return DropdownButtonFormField<String>(
                              initialValue: widget.hotelId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.apartment_outlined),
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: widget.hotelId,
                                  child: Text(
                                    hotel?.displayName ?? 'Current Hotel',
                                  ),
                                ),
                              ],
                              onChanged: null,
                            );
                          },
                          error: (error, stackTrace) =>
                              DropdownButtonFormField<String>(
                            initialValue: widget.hotelId,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.apartment_outlined),
                            ),
                            items: [
                              DropdownMenuItem(
                                value: widget.hotelId,
                                child: const Text('Current Hotel'),
                              ),
                            ],
                            onChanged: null,
                          ),
                          loading: () => const LinearProgressIndicator(),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          initialValue: _roomTypeId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.bed_outlined),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Select Room Type'),
                            ),
                            for (final roomType in typeItems)
                              DropdownMenuItem(
                                value: roomType.id,
                                child: Text(roomType.displayName),
                              ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _roomTypeId = value;
                              _selectedRoom = null;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const SrsFieldLabel('Room Status Grid'),
                  for (final group in _roomStatusGroups) ...[
                    _StatusGroupPanel(
                      group: group,
                      rooms: visibleRooms
                          .where((room) => room.status == group.status)
                          .toList(growable: false),
                      typeNames: typeNames,
                      selectedRoomId: selected?.id,
                      onSelectRoom: (room) =>
                          setState(() => _selectedRoom = room),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                  ],
                  if (selected != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _SelectedRoomPanel(
                      room: selected,
                      roomTypeName:
                          typeNames[selected.roomTypeId] ?? 'Room Type',
                      onOpen: () => _showRoomDetail(
                        context,
                        selected,
                        typeNames[selected.roomTypeId] ?? 'Room Type',
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  const _StatusLegend(groups: _roomStatusGroups),
                ],
              );
            },
            error: (error, stackTrace) => _BoardError(onRetry: _refresh),
            loading: () => const Center(child: CircularProgressIndicator()),
          ),
          error: (error, stackTrace) => _BoardError(onRetry: _refresh),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}

class _RoomStatusGroup {
  const _RoomStatusGroup({
    required this.status,
    required this.label,
    required this.icon,
  });

  final String status;
  final String label;
  final IconData icon;
}

const _roomStatusGroups = [
  _RoomStatusGroup(
    status: 'Available',
    label: 'Available',
    icon: Icons.check_circle_outline,
  ),
  _RoomStatusGroup(
    status: 'Assigned',
    label: 'Assigned',
    icon: Icons.person_outline,
  ),
  _RoomStatusGroup(
    status: 'Occupied',
    label: 'Occupied',
    icon: Icons.bed_outlined,
  ),
  _RoomStatusGroup(
    status: 'Dirty',
    label: 'Dirty',
    icon: Icons.delete_outline,
  ),
  _RoomStatusGroup(
    status: 'Cleaning',
    label: 'Cleaning',
    icon: Icons.cleaning_services_outlined,
  ),
  _RoomStatusGroup(
    status: 'InspectionRequired',
    label: 'Inspection Required',
    icon: Icons.assignment_turned_in_outlined,
  ),
  _RoomStatusGroup(
    status: 'Maintenance',
    label: 'Maintenance',
    icon: Icons.build_outlined,
  ),
  _RoomStatusGroup(
    status: 'OutOfService',
    label: 'Out of Service',
    icon: Icons.block_outlined,
  ),
  _RoomStatusGroup(
    status: 'Blocked',
    label: 'Blocked',
    icon: Icons.lock_outline,
  ),
  _RoomStatusGroup(
    status: 'Inactive',
    label: 'Inactive',
    icon: Icons.pause_circle_outline,
  ),
];

class _StatusGroupPanel extends StatelessWidget {
  const _StatusGroupPanel({
    required this.group,
    required this.rooms,
    required this.typeNames,
    required this.selectedRoomId,
    required this.onSelectRoom,
  });

  final _RoomStatusGroup group;
  final List<RoomInventoryItem> rooms;
  final Map<String, String> typeNames;
  final String? selectedRoomId;
  final ValueChanged<RoomInventoryItem> onSelectRoom;

  void _viewAll(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${group.label} Rooms (${rooms.length})',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: rooms.isEmpty
                  ? const Center(child: Text('No rooms in this status.'))
                  : GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 180,
                        childAspectRatio: 1.55,
                        crossAxisSpacing: AppSpacing.sm,
                        mainAxisSpacing: AppSpacing.sm,
                      ),
                      itemCount: rooms.length,
                      itemBuilder: (context, index) => _RoomTile(
                        room: rooms[index],
                        roomTypeName:
                            typeNames[rooms[index].roomTypeId] ?? 'Room Type',
                        icon: group.icon,
                        selected: selectedRoomId == rooms[index].id,
                        onTap: () {
                          onSelectRoom(rooms[index]);
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SrsPanel(
      padding: const EdgeInsets.all(AppSpacing.xs),
      child: Column(
        children: [
          Row(
            children: [
              Icon(group.icon, size: 20),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  '${group.label} (${rooms.length})',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              TextButton(
                onPressed: () => _viewAll(context),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('View All'),
                    Icon(Icons.chevron_right, size: 20),
                  ],
                ),
              ),
            ],
          ),
          if (rooms.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.sm),
                child: Text('No rooms'),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final room in rooms.take(6)) ...[
                    SizedBox(
                      width: 126,
                      child: _RoomTile(
                        room: room,
                        roomTypeName: typeNames[room.roomTypeId] ?? 'Room Type',
                        icon: group.icon,
                        selected: selectedRoomId == room.id,
                        onTap: () => onSelectRoom(room),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RoomTile extends StatelessWidget {
  const _RoomTile({
    required this.room,
    required this.roomTypeName,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final RoomInventoryItem room;
  final String roomTypeName;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.surfaceSoft : AppColors.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: selected ? AppColors.ink : AppColors.outlineSoft,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                room.roomNumber,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                roomTypeName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Icon(icon, size: 17),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedRoomPanel extends StatelessWidget {
  const _SelectedRoomPanel({
    required this.room,
    required this.roomTypeName,
    required this.onOpen,
  });

  final RoomInventoryItem room;
  final String roomTypeName;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return SrsPanel(
      child: Row(
        children: [
          _RoomTile(
            room: room,
            roomTypeName: roomTypeName,
            icon: _iconForRoomStatus(room.status),
            selected: true,
            onTap: onOpen,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selected Room: ${room.roomNumber}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text('$roomTypeName - ${_labelForRoomStatus(room.status)}'),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.description_outlined),
            label: const Text('Open Room Detail'),
          ),
        ],
      ),
    );
  }
}

class _StatusLegend extends StatelessWidget {
  const _StatusLegend({required this.groups});

  final List<_RoomStatusGroup> groups;

  @override
  Widget build(BuildContext context) {
    return SrsPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SrsSectionTitle('Status Legend'),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.sm,
            children: [
              for (final group in groups.take(8))
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(group.icon, size: 18),
                    const SizedBox(width: AppSpacing.xs),
                    Text(group.label),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BoardError extends StatelessWidget {
  const _BoardError({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        SrsPanel(
          child: Column(
            children: [
              const Icon(Icons.error_outline, color: AppColors.danger),
              const SizedBox(height: AppSpacing.sm),
              const Text('Unable to load the room status board.'),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(
                onPressed: onRetry,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

void _showRoomDetail(
  BuildContext context,
  RoomInventoryItem room,
  String roomTypeName,
) {
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Room ${room.roomNumber}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.lg),
          SrsSummaryRow(label: 'Room Type', value: roomTypeName),
          SrsSummaryRow(
            label: 'Status',
            value: _labelForRoomStatus(room.status),
          ),
          SrsSummaryRow(
            label: 'Floor',
            value: room.floor?.trim().isNotEmpty == true
                ? room.floor!
                : 'Not specified',
          ),
          SrsSummaryRow(
            label: 'Notes',
            value: room.notes?.trim().isNotEmpty == true
                ? room.notes!
                : 'No room notes',
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    ),
  );
}

String _labelForRoomStatus(String status) {
  return switch (status) {
    'InspectionRequired' => 'Inspection Required',
    'OutOfService' => 'Out of Service',
    _ => status,
  };
}

IconData _iconForRoomStatus(String status) {
  for (final group in _roomStatusGroups) {
    if (group.status == status) {
      return group.icon;
    }
  }
  return Icons.meeting_room_outlined;
}
