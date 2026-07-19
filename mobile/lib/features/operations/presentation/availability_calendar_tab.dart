import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../shared/utils/app_formatters.dart';
import '../../../shared/widgets/app_error_presenter.dart';
import '../../../shared/widgets/app_text_form_field.dart';
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
  late DateTime _startDate;
  late DateTime _endDate;
  String? _roomTypeFilter;
  String? _physicalRoomFilter;

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
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);
    _endDate = _startDate.add(const Duration(days: 14));
  }

  Future<void> _selectDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      helpText: 'Select inventory window',
    );
    if (range == null || !mounted) {
      return;
    }

    setState(() {
      _startDate =
          DateTime(range.start.year, range.start.month, range.start.day);
      _endDate = DateTime(range.end.year, range.end.month, range.end.day);
    });
  }

  Future<void> _openChangeSheet(AvailabilityCalendar calendar) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      builder: (context) => _AvailabilityChangeSheet(
        hotelId: widget.hotelId,
        calendar: calendar,
        initialStartDate: _startDate,
        initialEndDate: _endDate,
        initialRoomTypeId: _roomTypeFilter,
        initialPhysicalRoomId: _physicalRoomFilter,
        receptionistOnly: _isReceptionistOnly,
      ),
    );

    if (changed == true) {
      ref.invalidate(availabilityCalendarProvider(_request));
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Availability has been updated.')),
          );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final calendarState = ref.watch(availabilityCalendarProvider(_request));

    return RefreshIndicator(
      onRefresh: () async =>
          ref.invalidate(availabilityCalendarProvider(_request)),
      child: calendarState.when(
        loading: () => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 280),
            Center(child: CircularProgressIndicator()),
          ],
        ),
        error: (error, stackTrace) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            const SizedBox(height: 160),
            Icon(
              Icons.calendar_month_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.outline,
            ),
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
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: () =>
                  ref.invalidate(availabilityCalendarProvider(_request)),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
        data: (calendar) => _buildCalendar(context, calendar),
      ),
    );
  }

  Widget _buildCalendar(BuildContext context, AvailabilityCalendar calendar) {
    final selectedRoomType = calendar.roomTypes
        .where((roomType) => roomType.id == _roomTypeFilter)
        .firstOrNull;
    final rooms = selectedRoomType?.physicalRooms ??
        calendar.roomTypes
            .expand((roomType) => roomType.physicalRooms)
            .toList();
    final selectedRoomExists =
        rooms.any((room) => room.id == _physicalRoomFilter);
    final effectivePhysicalRoomFilter =
        selectedRoomExists ? _physicalRoomFilter : null;

    final entries = calendar.entries.where((entry) {
      return (_roomTypeFilter == null || entry.roomTypeId == _roomTypeFilter) &&
          (effectivePhysicalRoomFilter == null ||
              entry.physicalRoomId == effectivePhysicalRoomFilter);
    }).toList(growable: false);
    final commitments = calendar.activeCommitments.where((commitment) {
      return _roomTypeFilter == null ||
          commitment.roomTypeId == _roomTypeFilter;
    }).toList(growable: false);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Inventory calendar',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              _isReceptionistOnly
                  ? 'View commitments and temporarily block or unblock individual rooms.'
                  : 'Control sellable dates while protecting active reservations.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: () => _openChangeSheet(calendar),
              icon: const Icon(Icons.edit_calendar_rounded),
              label: const Text('Update'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        OutlinedButton.icon(
          onPressed: _selectDateRange,
          icon: const Icon(Icons.date_range_rounded),
          label: Text(
            '${AppFormatters.displayDate(_startDate)} - ${AppFormatters.displayDate(_endDate)}',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<String?>(
          initialValue: _roomTypeFilter,
          decoration: const InputDecoration(
            labelText: 'Room type',
            prefixIcon: Icon(Icons.bed_rounded),
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('All room types'),
            ),
            for (final roomType in calendar.roomTypes)
              DropdownMenuItem<String?>(
                value: roomType.id,
                child: Text(roomType.name),
              ),
          ],
          onChanged: (value) {
            setState(() {
              _roomTypeFilter = value;
              _physicalRoomFilter = null;
            });
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<String?>(
          initialValue: effectivePhysicalRoomFilter,
          decoration: const InputDecoration(
            labelText: 'Physical room',
            prefixIcon: Icon(Icons.meeting_room_rounded),
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('All physical rooms'),
            ),
            for (final room in rooms)
              DropdownMenuItem<String?>(
                value: room.id,
                child: Text('Room ${room.roomNumber} - ${room.status}'),
              ),
          ],
          onChanged: (value) => setState(() => _physicalRoomFilter = value),
        ),
        const SizedBox(height: AppSpacing.lg),
        _AvailabilitySummary(
          roomCount: rooms.length,
          restrictionCount: entries.length,
          commitmentCount: commitments.length,
        ),
        const SizedBox(height: AppSpacing.lg),
        _DateStrip(
          startDate: _startDate,
          endDate: _endDate,
          entries: entries,
          commitments: commitments,
        ),
        const SizedBox(height: AppSpacing.xl),
        _SectionHeader(
          title: 'Restrictions',
          count: entries.length,
          icon: Icons.event_busy_rounded,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (entries.isEmpty)
          const _AvailabilityEmptyState(
            icon: Icons.event_available_rounded,
            message: 'No closed or blocked dates in this window.',
          )
        else
          for (final entry in entries) ...[
            _AvailabilityEntryCard(
              entry: entry,
              roomType: calendar.roomTypes
                  .where((roomType) => roomType.id == entry.roomTypeId)
                  .firstOrNull,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        const SizedBox(height: AppSpacing.lg),
        _SectionHeader(
          title: 'Active commitments',
          count: commitments.length,
          icon: Icons.book_online_rounded,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (commitments.isEmpty)
          const _AvailabilityEmptyState(
            icon: Icons.hotel_class_outlined,
            message: 'No active reservations overlap this window.',
          )
        else
          for (final commitment in commitments) ...[
            _CommitmentCard(
              commitment: commitment,
              roomTypeName: calendar.roomTypes
                      .where((roomType) => roomType.id == commitment.roomTypeId)
                      .firstOrNull
                      ?.name ??
                  'Room type',
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
      ],
    );
  }
}

class _AvailabilityChangeSheet extends ConsumerStatefulWidget {
  const _AvailabilityChangeSheet({
    required this.hotelId,
    required this.calendar,
    required this.initialStartDate,
    required this.initialEndDate,
    required this.initialRoomTypeId,
    required this.initialPhysicalRoomId,
    required this.receptionistOnly,
  });

  final String hotelId;
  final AvailabilityCalendar calendar;
  final DateTime initialStartDate;
  final DateTime initialEndDate;
  final String? initialRoomTypeId;
  final String? initialPhysicalRoomId;
  final bool receptionistOnly;

  @override
  ConsumerState<_AvailabilityChangeSheet> createState() =>
      _AvailabilityChangeSheetState();
}

class _AvailabilityChangeSheetState
    extends ConsumerState<_AvailabilityChangeSheet> {
  final _reasonController = TextEditingController();
  late DateTime _startDate;
  late DateTime _endDate;
  late String? _roomTypeId;
  late String? _physicalRoomId;
  late AvailabilityChangeAction _action;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialStartDate;
    _endDate = widget.initialEndDate;
    _roomTypeId = widget.initialRoomTypeId ??
        (widget.calendar.roomTypes.isEmpty
            ? null
            : widget.calendar.roomTypes.first.id);
    final rooms = _selectedRooms;
    _physicalRoomId = widget.initialPhysicalRoomId ??
        (widget.receptionistOnly && rooms.isNotEmpty ? rooms.first.id : null);
    _action = widget.receptionistOnly
        ? AvailabilityChangeAction.block
        : _physicalRoomId == null
            ? AvailabilityChangeAction.close
            : AvailabilityChangeAction.block;
  }

  List<AvailabilityPhysicalRoom> get _selectedRooms {
    return widget.calendar.roomTypes
            .where((roomType) => roomType.id == _roomTypeId)
            .firstOrNull
            ?.physicalRooms ??
        const [];
  }

  List<AvailabilityChangeAction> get _availableActions {
    if (_physicalRoomId == null) {
      return const [
        AvailabilityChangeAction.close,
        AvailabilityChangeAction.open,
      ];
    }

    return const [
      AvailabilityChangeAction.block,
      AvailabilityChangeAction.unblock,
    ];
  }

  bool get _requiresReason =>
      _action == AvailabilityChangeAction.close ||
      _action == AvailabilityChangeAction.block;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _selectDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );
    if (range != null && mounted) {
      setState(() {
        _startDate =
            DateTime(range.start.year, range.start.month, range.start.day);
        _endDate = DateTime(range.end.year, range.end.month, range.end.day);
      });
    }
  }

  Future<void> _submit() async {
    if (_roomTypeId == null) {
      AppErrorPresenter.showSnackBar(context, 'Select a room type.');
      return;
    }
    if (widget.receptionistOnly && _physicalRoomId == null) {
      AppErrorPresenter.showSnackBar(
        context,
        'Receptionists must select one physical room.',
      );
      return;
    }
    if (_requiresReason && _reasonController.text.trim().isEmpty) {
      AppErrorPresenter.showSnackBar(
        context,
        'Enter a clear operational reason.',
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(operationsApiProvider).changeAvailability(
            hotelId: widget.hotelId,
            roomTypeId: _roomTypeId!,
            physicalRoomId: _physicalRoomId,
            startDate: _startDate,
            endDate: _endDate,
            action: _action,
            reason: _requiresReason ? _reasonController.text : null,
          );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        await AppErrorPresenter.showBottomSheet(
          context,
          error,
          title: 'Availability not updated',
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
    final rooms = _selectedRooms;
    final actions = _availableActions;
    if (!actions.contains(_action)) {
      _action = actions.first;
    }

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.xl,
          right: AppSpacing.xl,
          bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Update availability',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                widget.receptionistOnly
                    ? 'Your role can block or unblock one physical room at a time.'
                    : 'Closing a room type removes it from public sale for the selected dates.',
              ),
              const SizedBox(height: AppSpacing.lg),
              DropdownButtonFormField<String>(
                initialValue: _roomTypeId,
                decoration: const InputDecoration(labelText: 'Room type'),
                items: [
                  for (final roomType in widget.calendar.roomTypes)
                    DropdownMenuItem(
                      value: roomType.id,
                      child: Text(roomType.name),
                    ),
                ],
                onChanged: _submitting
                    ? null
                    : (value) {
                        setState(() {
                          _roomTypeId = value;
                          final selectedRooms = _selectedRooms;
                          _physicalRoomId = widget.receptionistOnly &&
                                  selectedRooms.isNotEmpty
                              ? selectedRooms.first.id
                              : null;
                        });
                      },
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<String?>(
                initialValue: _physicalRoomId,
                decoration: const InputDecoration(labelText: 'Scope'),
                items: [
                  if (!widget.receptionistOnly)
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Entire room type'),
                    ),
                  for (final room in rooms)
                    DropdownMenuItem<String?>(
                      value: room.id,
                      child: Text('Room ${room.roomNumber} - ${room.status}'),
                    ),
                ],
                onChanged: _submitting
                    ? null
                    : (value) {
                        setState(() {
                          _physicalRoomId = value;
                          _action = value == null
                              ? AvailabilityChangeAction.close
                              : AvailabilityChangeAction.block;
                        });
                      },
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<AvailabilityChangeAction>(
                initialValue: _action,
                decoration: const InputDecoration(labelText: 'Action'),
                items: [
                  for (final action in actions)
                    DropdownMenuItem(
                      value: action,
                      child: Text(action.label),
                    ),
                ],
                onChanged: _submitting
                    ? null
                    : (value) => setState(() => _action = value ?? _action),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: _submitting ? null : _selectDateRange,
                icon: const Icon(Icons.date_range_rounded),
                label: Text(
                  '${AppFormatters.displayDate(_startDate)} - ${AppFormatters.displayDate(_endDate)}',
                ),
              ),
              if (_requiresReason) ...[
                const SizedBox(height: AppSpacing.sm),
                AppTextFormField(
                  controller: _reasonController,
                  labelText: 'Operational reason',
                  hintText: 'Explain why inventory must be restricted',
                  maxLines: 3,
                  textInputAction: TextInputAction.done,
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(_submitting ? 'Saving' : 'Apply change'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvailabilitySummary extends StatelessWidget {
  const _AvailabilitySummary({
    required this.roomCount,
    required this.restrictionCount,
    required this.commitmentCount,
  });

  final int roomCount;
  final int restrictionCount;
  final int commitmentCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _SummaryTile(label: 'Rooms', value: roomCount)),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: _SummaryTile(
            label: 'Restrictions',
            value: restrictionCount,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: _SummaryTile(
            label: 'Bookings',
            value: commitmentCount,
          ),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Column(
        children: [
          Text(value.toString(), style: Theme.of(context).textTheme.titleLarge),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _DateStrip extends StatelessWidget {
  const _DateStrip({
    required this.startDate,
    required this.endDate,
    required this.entries,
    required this.commitments,
  });

  final DateTime startDate;
  final DateTime endDate;
  final List<AvailabilityEntry> entries;
  final List<AvailabilityCommitment> commitments;

  @override
  Widget build(BuildContext context) {
    final requestedDays = endDate.difference(startDate).inDays;
    final dayCount = requestedDays.clamp(1, 31);

    return SizedBox(
      height: 116,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: dayCount,
        separatorBuilder: (context, index) =>
            const SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, index) {
          final day = startDate.add(Duration(days: index));
          final nextDay = day.add(const Duration(days: 1));
          final restrictionCount = entries.where((entry) {
            return entry.startDate.isBefore(nextDay) &&
                entry.endDate.isAfter(day);
          }).length;
          final bookingCount = commitments.where((commitment) {
            return commitment.checkInDate.isBefore(nextDay) &&
                commitment.checkOutDate.isAfter(day);
          }).length;

          return Container(
            width: 88,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: restrictionCount > 0
                  ? AppColors.warningSoft
                  : AppColors.surface,
              border: Border.all(color: AppColors.outline),
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${day.day}/${day.month}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text('$bookingCount booked'),
                Text('$restrictionCount blocked'),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    required this.icon,
  });

  final String title;
  final int count;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.brand),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        Text(count.toString()),
      ],
    );
  }
}

class _AvailabilityEntryCard extends StatelessWidget {
  const _AvailabilityEntryCard({required this.entry, required this.roomType});

  final AvailabilityEntry entry;
  final AvailabilityRoomType? roomType;

  @override
  Widget build(BuildContext context) {
    final room = roomType?.physicalRooms
        .where((room) => room.id == entry.physicalRoomId)
        .firstOrNull;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.warningSoft,
          foregroundColor: AppColors.warning,
          child: Icon(
            entry.status == 'Closed'
                ? Icons.event_busy_rounded
                : Icons.block_rounded,
          ),
        ),
        title: Text(
          room == null
              ? '${roomType?.name ?? 'Room type'} - ${entry.status}'
              : 'Room ${room.roomNumber} - ${entry.status}',
        ),
        subtitle: Text(
          '${AppFormatters.displayDate(entry.startDate)} - ${AppFormatters.displayDate(entry.endDate)}\n${entry.reason}',
        ),
        isThreeLine: true,
      ),
    );
  }
}

class _CommitmentCard extends StatelessWidget {
  const _CommitmentCard({
    required this.commitment,
    required this.roomTypeName,
  });

  final AvailabilityCommitment commitment;
  final String roomTypeName;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: AppColors.successSoft,
          foregroundColor: AppColors.success,
          child: Icon(Icons.book_online_rounded),
        ),
        title: Text('Booking ${commitment.bookingCode}'),
        subtitle: Text(
          '$roomTypeName - ${commitment.roomCount} room${commitment.roomCount == 1 ? '' : 's'}\n'
          '${AppFormatters.displayDate(commitment.checkInDate)} - ${AppFormatters.displayDate(commitment.checkOutDate)}',
        ),
        trailing: Text(commitment.status),
        isThreeLine: true,
      ),
    );
  }
}

class _AvailabilityEmptyState extends StatelessWidget {
  const _AvailabilityEmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.mutedInk),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}
