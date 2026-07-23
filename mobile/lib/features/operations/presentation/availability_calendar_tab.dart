import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../shared/utils/app_formatters.dart';
import '../../../shared/widgets/app_error_presenter.dart';
import '../../../shared/widgets/app_text_form_field.dart';
import '../../../shared/widgets/srs_screen.dart';
import '../../auth/domain/auth_models.dart';
import '../application/operations_providers.dart';
import '../domain/operations_models.dart';

class AvailabilityCalendarTab extends ConsumerStatefulWidget {
  const AvailabilityCalendarTab({
    super.key,
    required this.hotelId,
    required this.roles,
  });

  final String hotelId;
  final List<String> roles;

  @override
  ConsumerState<AvailabilityCalendarTab> createState() =>
      _AvailabilityCalendarTabState();
}

class _AvailabilityCalendarTabState
    extends ConsumerState<AvailabilityCalendarTab> {
  final _reasonController = TextEditingController();
  late DateTime _startDate;
  late DateTime _endDate;
  String? _roomTypeFilter;
  String? _physicalRoomFilter;
  AvailabilityChangeAction? _action;
  bool _saving = false;

  bool get _isReceptionistOnly {
    return widget.roles.contains(UserRoleCode.receptionist.apiValue) &&
        !widget.roles.contains(UserRoleCode.propertyOwner.apiValue) &&
        !widget.roles.contains(UserRoleCode.hotelManager.apiValue);
  }

  AvailabilityCalendarRequest get _request => AvailabilityCalendarRequest(
        hotelId: widget.hotelId,
        startDate: _startDate,
        endDate: _endDate,
      );

  @override
  void initState() {
    super.initState();
    final now = DateUtils.dateOnly(DateTime.now());
    _startDate = now;
    _endDate = now.add(const Duration(days: 6));
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _selectDateRange() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final range = await showDateRangePicker(
      context: context,
      firstDate: today,
      lastDate: today.add(const Duration(days: 730)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      helpText: 'Select availability date range',
    );
    if (range != null && mounted) {
      setState(() {
        _startDate = DateUtils.dateOnly(range.start);
        _endDate = DateUtils.dateOnly(range.end);
      });
    }
  }

  Future<void> _save(AvailabilityCalendar calendar) async {
    final action = _action;
    String? roomTypeId = _roomTypeFilter;
    if (roomTypeId == null && _physicalRoomFilter != null) {
      roomTypeId = _roomTypeForRoom(
        calendar.roomTypes,
        _physicalRoomFilter!,
      )?.id;
    }
    if (roomTypeId == null) {
      AppErrorPresenter.showSnackBar(context, 'Select a room type.');
      return;
    }
    if (_isReceptionistOnly && _physicalRoomFilter == null) {
      AppErrorPresenter.showSnackBar(
        context,
        'Receptionists must select one physical room.',
      );
      return;
    }
    if (action == null) {
      AppErrorPresenter.showSnackBar(context, 'Select an action.');
      return;
    }
    final requiresReason = action == AvailabilityChangeAction.close ||
        action == AvailabilityChangeAction.block;
    if (requiresReason && _reasonController.text.trim().isEmpty) {
      AppErrorPresenter.showSnackBar(
        context,
        'Enter a reason for closing or blocking inventory.',
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(operationsApiProvider).changeAvailability(
            hotelId: widget.hotelId,
            roomTypeId: roomTypeId,
            physicalRoomId: _physicalRoomFilter,
            startDate: _startDate,
            endDate: _endDate,
            action: action,
            reason: requiresReason ? _reasonController.text : null,
          );
      _reasonController.clear();
      setState(() => _action = null);
      ref.invalidate(availabilityCalendarProvider(_request));
      if (mounted) {
        AppErrorPresenter.showSnackBar(context, 'Availability updated.');
      }
    } catch (error) {
      if (mounted) {
        await AppErrorPresenter.showBottomSheet(
          context,
          error,
          title: 'Availability Not Updated',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final calendar = ref.watch(availabilityCalendarProvider(_request));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(availabilityCalendarProvider(_request));
      },
      child: calendar.when(
        loading: () => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 260),
            Center(child: CircularProgressIndicator()),
          ],
        ),
        error: (error, stackTrace) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            const SizedBox(height: AppSpacing.xxl),
            _ErrorPanel(
              error: error,
              onRetry: () =>
                  ref.invalidate(availabilityCalendarProvider(_request)),
            ),
          ],
        ),
        data: _buildCalendar,
      ),
    );
  }

  Widget _buildCalendar(AvailabilityCalendar calendar) {
    final selectedType = calendar.roomTypes.where((roomType) {
      return roomType.id == _roomTypeFilter;
    }).firstOrNull;
    final filterRooms = selectedType?.physicalRooms ??
        calendar.roomTypes
            .expand((roomType) => roomType.physicalRooms)
            .toList(growable: false);
    final physicalRoomFilter =
        filterRooms.any((room) => room.id == _physicalRoomFilter)
            ? _physicalRoomFilter
            : null;
    final displayedRooms = filterRooms.where((room) {
      return physicalRoomFilter == null || room.id == physicalRoomFilter;
    }).toList(growable: false);
    final availableActions = physicalRoomFilter == null && !_isReceptionistOnly
        ? const [
            AvailabilityChangeAction.close,
            AvailabilityChangeAction.open,
          ]
        : const [
            AvailabilityChangeAction.block,
            AvailabilityChangeAction.unblock,
          ];
    final safeAction = availableActions.contains(_action) ? _action : null;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SrsFieldLabel('Room Type Filter'),
                  DropdownButtonFormField<String?>(
                    initialValue: _roomTypeFilter,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.bed_rounded),
                    ),
                    hint: const Text('Select Room Type'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All Room Types'),
                      ),
                      for (final roomType in calendar.roomTypes)
                        DropdownMenuItem(
                          value: roomType.id,
                          child: Text(
                            roomType.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _roomTypeFilter = value;
                        _physicalRoomFilter = null;
                        _action = null;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SrsFieldLabel('Physical Room Filter'),
                  DropdownButtonFormField<String?>(
                    initialValue: physicalRoomFilter,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.meeting_room_outlined),
                    ),
                    hint: const Text('Select Physical Room'),
                    items: [
                      if (!_isReceptionistOnly)
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All Rooms'),
                        ),
                      for (final room in filterRooms)
                        DropdownMenuItem(
                          value: room.id,
                          child: Text(
                            'Room ${room.roomNumber}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _physicalRoomFilter = value;
                        if (value != null && _roomTypeFilter == null) {
                          _roomTypeFilter =
                              _roomTypeForRoom(calendar.roomTypes, value)?.id;
                        }
                        _action = null;
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        const SrsFieldLabel('Date Range'),
        InkWell(
          onTap: _selectDateRange,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          child: Container(
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.outline),
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_month_outlined),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    '${AppFormatters.displayDate(_startDate)} - '
                    '${AppFormatters.displayDate(_endDate)}',
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const SrsFieldLabel('Availability Calendar'),
        _AvailabilityGrid(
          startDate: _startDate,
          endDate: _endDate,
          roomTypes: calendar.roomTypes,
          rooms: displayedRooms,
          entries: calendar.entries,
          commitments: calendar.activeCommitments,
        ),
        const SizedBox(height: AppSpacing.md),
        const SrsFieldLabel('Action'),
        DropdownButtonFormField<AvailabilityChangeAction>(
          initialValue: safeAction,
          isExpanded: true,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.check_box_outline_blank_rounded),
          ),
          hint: const Text('Select action'),
          items: [
            for (final action in availableActions)
              DropdownMenuItem(
                value: action,
                child: Text(action.label),
              ),
          ],
          onChanged:
              _saving ? null : (value) => setState(() => _action = value),
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextFormField(
          controller: _reasonController,
          labelText: 'Reason',
          hintText: 'Enter reason',
          externalLabel: true,
          maxLines: 3,
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: _saving ? null : () => _save(calendar),
          child: _saving
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

class _AvailabilityGrid extends StatelessWidget {
  const _AvailabilityGrid({
    required this.startDate,
    required this.endDate,
    required this.roomTypes,
    required this.rooms,
    required this.entries,
    required this.commitments,
  });

  final DateTime startDate;
  final DateTime endDate;
  final List<AvailabilityRoomType> roomTypes;
  final List<AvailabilityPhysicalRoom> rooms;
  final List<AvailabilityEntry> entries;
  final List<AvailabilityCommitment> commitments;

  @override
  Widget build(BuildContext context) {
    if (rooms.isEmpty) {
      return const SrsPanel(
        child: Text('No physical rooms match the selected filters.'),
      );
    }

    final requestedDays = endDate.difference(startDate).inDays + 1;
    final dayCount = requestedDays.clamp(1, 7);
    final days = List<DateTime>.generate(
      dayCount,
      (index) => startDate.add(Duration(days: index)),
    );
    const roomWidth = 118.0;
    const dayWidth = 92.0;
    final roomTypeByRoomId = <String, AvailabilityRoomType>{
      for (final roomType in roomTypes)
        for (final room in roomType.physicalRooms) room.id: roomType,
    };

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.outline),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: roomWidth + (dayWidth * days.length),
          child: Column(
            children: [
              Row(
                children: [
                  const _HeaderCell(width: roomWidth, title: 'Room'),
                  for (final day in days)
                    _HeaderCell(
                      width: dayWidth,
                      title: '${_monthName(day.month)} ${day.day}\n'
                          '${_weekday(day.weekday)}',
                    ),
                ],
              ),
              for (final room in rooms)
                Row(
                  children: [
                    _RoomCell(
                      width: roomWidth,
                      roomNumber: room.roomNumber,
                      roomTypeName:
                          roomTypeByRoomId[room.id]?.name ?? 'Room Type',
                    ),
                    for (final day in days)
                      _StateCell(
                        width: dayWidth,
                        state: _stateFor(
                          room: room,
                          roomTypeId: roomTypeByRoomId[room.id]?.id ?? '',
                          day: day,
                        ),
                      ),
                  ],
                ),
              const Padding(
                padding: EdgeInsets.all(AppSpacing.sm),
                child: Wrap(
                  spacing: AppSpacing.lg,
                  runSpacing: AppSpacing.xs,
                  children: [
                    _Legend(
                      icon: Icons.check_circle_outline_rounded,
                      label: 'Available',
                    ),
                    _Legend(
                      icon: Icons.calendar_month_outlined,
                      label: 'Booked',
                    ),
                    _Legend(
                      icon: Icons.handyman_outlined,
                      label: 'Maintenance',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _CalendarState _stateFor({
    required AvailabilityPhysicalRoom room,
    required String roomTypeId,
    required DateTime day,
  }) {
    final nextDay = day.add(const Duration(days: 1));
    final restriction = entries.where((entry) {
      return entry.roomTypeId == roomTypeId &&
          (entry.physicalRoomId == null || entry.physicalRoomId == room.id) &&
          entry.startDate.isBefore(nextDay) &&
          entry.endDate.isAfter(day);
    }).firstOrNull;
    if (restriction != null) {
      return const _CalendarState(
        label: 'Maintenance',
        icon: Icons.handyman_outlined,
      );
    }

    final booking = commitments.where((commitment) {
      return commitment.roomTypeId == roomTypeId &&
          commitment.assignedPhysicalRoomIds.contains(room.id) &&
          commitment.checkInDate.isBefore(nextDay) &&
          commitment.checkOutDate.isAfter(day);
    }).firstOrNull;
    if (booking != null) {
      return const _CalendarState(
        label: 'Booked',
        icon: Icons.calendar_month_outlined,
      );
    }

    if (room.status != 'Available') {
      return _CalendarState(
        label: _roomStatusLabel(room.status),
        icon: Icons.handyman_outlined,
      );
    }

    return const _CalendarState(
      label: 'Available',
      icon: Icons.check_circle_outline_rounded,
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({required this.width, required this.title});

  final double width;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 64,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: const BoxDecoration(
        border: Border(
          right: BorderSide(color: AppColors.outlineSoft),
          bottom: BorderSide(color: AppColors.outlineSoft),
        ),
      ),
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _RoomCell extends StatelessWidget {
  const _RoomCell({
    required this.width,
    required this.roomNumber,
    required this.roomTypeName,
  });

  final double width;
  final String roomNumber;
  final String roomTypeName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 90,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: const BoxDecoration(
        border: Border(
          right: BorderSide(color: AppColors.outlineSoft),
          bottom: BorderSide(color: AppColors.outlineSoft),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(roomNumber, style: Theme.of(context).textTheme.titleSmall),
          Text(
            roomTypeName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _StateCell extends StatelessWidget {
  const _StateCell({required this.width, required this.state});

  final double width;
  final _CalendarState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 90,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(AppSpacing.xxs),
      decoration: const BoxDecoration(
        border: Border(
          right: BorderSide(color: AppColors.outlineSoft),
          bottom: BorderSide(color: AppColors.outlineSoft),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(state.icon),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            state.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _CalendarState {
  const _CalendarState({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

class _Legend extends StatelessWidget {
  const _Legend({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: AppSpacing.xs),
        Text(label),
      ],
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SrsPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.calendar_month_outlined, size: 48),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Unable to load availability',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            AppErrorPresenter.friendlyMessage(error),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(onPressed: onRetry, child: const Text('Try Again')),
        ],
      ),
    );
  }
}

AvailabilityRoomType? _roomTypeForRoom(
  List<AvailabilityRoomType> roomTypes,
  String roomId,
) {
  return roomTypes.where((roomType) {
    return roomType.physicalRooms.any((room) => room.id == roomId);
  }).firstOrNull;
}

String _weekday(int weekday) {
  return const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][weekday - 1];
}

String _monthName(int month) {
  return const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][month - 1];
}

String _roomStatusLabel(String value) {
  return switch (value) {
    'Occupied' || 'Assigned' => 'Booked',
    'Maintenance' || 'OutOfService' || 'Blocked' => 'Maintenance',
    'Dirty' || 'Cleaning' || 'InspectionRequired' => 'Maintenance',
    _ => value,
  };
}
