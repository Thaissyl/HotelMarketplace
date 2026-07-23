import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../shared/widgets/app_error_presenter.dart';
import '../../auth/application/auth_controller.dart';
import '../application/operations_providers.dart';
import '../domain/operations_models.dart';

class MaintenanceTab extends ConsumerStatefulWidget {
  const MaintenanceTab({super.key, required this.hotelId});

  final String hotelId;

  @override
  ConsumerState<MaintenanceTab> createState() => _MaintenanceTabState();
}

class _MaintenanceTabState extends ConsumerState<MaintenanceTab> {
  static const int _pageSize = 5;

  final _roomSearch = TextEditingController();
  final _requestRoomSearch = TextEditingController();
  final _description = TextEditingController();
  String? _selectedRoomId;
  MaintenanceSeverity _severity = MaintenanceSeverity.medium;
  MaintenanceStatus? _statusFilter;
  MaintenanceSeverity? _severityFilter;
  String _assigneeFilter = 'All';
  String _targetStatus = 'Maintenance';
  bool _reporting = false;
  int _pageIndex = 0;

  void _setStatusFilter(MaintenanceStatus? status) {
    setState(() {
      _statusFilter = status;
      _pageIndex = 0;
    });
  }

  void _goToPage(int pageIndex, int pageCount) {
    setState(() {
      _pageIndex = pageIndex.clamp(0, pageCount - 1);
    });
  }

  @override
  void dispose() {
    _roomSearch.dispose();
    _requestRoomSearch.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _reportIssue() async {
    if (_selectedRoomId == null || _description.text.trim().isEmpty) {
      AppErrorPresenter.showSnackBar(
        context,
        'Select a room and enter an issue description.',
      );
      return;
    }

    setState(() => _reporting = true);
    try {
      await ref.read(operationsApiProvider).reportMaintenanceIssue(
            hotelId: widget.hotelId,
            physicalRoomId: _selectedRoomId!,
            description: _description.text,
            severity: _severity,
            targetRoomStatus: _targetStatus,
          );
      _description.clear();
      setState(() => _selectedRoomId = null);
      ref.invalidate(
        maintenanceRequestsProvider(
          MaintenanceRequestsRequest(hotelId: widget.hotelId),
        ),
      );
      ref.invalidate(maintenanceRoomsProvider(widget.hotelId));
    } catch (error) {
      if (mounted) {
        await AppErrorPresenter.showBottomSheet(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _reporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = MaintenanceRequestsRequest(
      hotelId: widget.hotelId,
      status: _statusFilter,
    );
    final requests = ref.watch(maintenanceRequestsProvider(request));
    final rooms = ref.watch(maintenanceRoomsProvider(widget.hotelId));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(maintenanceRequestsProvider(request));
        ref.invalidate(maintenanceRoomsProvider(widget.hotelId));
      },
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            'Maintenance control',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Track room issues, remove affected rooms from sale, and release rooms after repair.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          requests.when(
            data: (items) => _MaintenanceSummary(requests: items),
            error: (error, stackTrace) => const SizedBox.shrink(),
            loading: () => const LinearProgressIndicator(),
          ),
          const SizedBox(height: AppSpacing.md),
          rooms.when(
            data: (roomItems) => _ReportIssueCard(
              rooms: roomItems,
              selectedRoomId: _selectedRoomId,
              roomSearch: _roomSearch,
              description: _description,
              severity: _severity,
              targetStatus: _targetStatus,
              reporting: _reporting,
              onRoomSelected: (value) =>
                  setState(() => _selectedRoomId = value),
              onSeverityChanged: (value) => setState(() => _severity = value),
              onTargetChanged: (value) => setState(() => _targetStatus = value),
              onSubmit: _reportIssue,
            ),
            error: (error, stackTrace) => _OperationErrorCard(
              message: 'Unable to load rooms for maintenance.',
              onRetry: () =>
                  ref.invalidate(maintenanceRoomsProvider(widget.hotelId)),
            ),
            loading: () => const Card(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: LinearProgressIndicator(),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DropdownButtonFormField<MaintenanceSeverity?>(
                  initialValue: _severityFilter,
                  decoration: const InputDecoration(
                    labelText: 'Severity',
                    prefixIcon: Icon(Icons.priority_high_rounded),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All severities'),
                    ),
                    for (final severity in MaintenanceSeverity.values)
                      DropdownMenuItem(
                        value: severity,
                        child: Text(severity.apiValue),
                      ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _severityFilter = value;
                      _pageIndex = 0;
                    });
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  controller: _requestRoomSearch,
                  decoration: const InputDecoration(
                    labelText: 'Room filter',
                    hintText: 'Room number',
                    prefixIcon: Icon(Icons.meeting_room_outlined),
                  ),
                  onChanged: (_) {
                    setState(() => _pageIndex = 0);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _MaintenanceStatusFilter(
            selectedStatus: _statusFilter,
            onChanged: _setStatusFilter,
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            initialValue: _assigneeFilter,
            decoration: const InputDecoration(
              labelText: 'Assignee',
              prefixIcon: Icon(Icons.engineering_outlined),
            ),
            items: const [
              DropdownMenuItem(value: 'All', child: Text('All requests')),
              DropdownMenuItem(value: 'Mine', child: Text('Assigned to me')),
              DropdownMenuItem(
                value: 'Unassigned',
                child: Text('Unassigned'),
              ),
            ],
            onChanged: (value) {
              setState(() {
                _assigneeFilter = value ?? 'All';
                _pageIndex = 0;
              });
            },
          ),
          const SizedBox(height: AppSpacing.md),
          requests.when(
            data: (items) {
              final currentUserId =
                  ref.read(authControllerProvider).userSession?.userId;
              final roomTerm = _requestRoomSearch.text.trim().toLowerCase();
              final filteredItems = items.where((item) {
                final matchesSeverity = _severityFilter == null ||
                    item.severity == _severityFilter!.apiValue;
                final matchesRoom = roomTerm.isEmpty ||
                    item.roomNumber.toLowerCase().contains(roomTerm);
                final matchesAssignee = switch (_assigneeFilter) {
                  'Mine' => item.assignedToUserAccountId == currentUserId,
                  'Unassigned' => item.assignedToUserAccountId == null,
                  _ => true,
                };
                return matchesSeverity && matchesRoom && matchesAssignee;
              }).toList(growable: false);

              if (filteredItems.isEmpty) {
                return const _EmptyMaintenance();
              }

              return _MaintenanceRequestList(
                hotelId: widget.hotelId,
                items: filteredItems,
                pageIndex: _pageIndex,
                pageSize: _pageSize,
                onPageChanged: _goToPage,
                onUpdated: () {
                  ref.invalidate(maintenanceRequestsProvider(request));
                  ref.invalidate(maintenanceRoomsProvider(widget.hotelId));
                },
              );
            },
            error: (error, stackTrace) => _OperationErrorCard(
              message: 'Unable to load maintenance requests.',
              onRetry: () =>
                  ref.invalidate(maintenanceRequestsProvider(request)),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
    );
  }
}

class _ReportIssueCard extends StatefulWidget {
  const _ReportIssueCard({
    required this.rooms,
    required this.selectedRoomId,
    required this.roomSearch,
    required this.description,
    required this.severity,
    required this.targetStatus,
    required this.reporting,
    required this.onRoomSelected,
    required this.onSeverityChanged,
    required this.onTargetChanged,
    required this.onSubmit,
  });

  final List<RoomInventoryItem> rooms;
  final String? selectedRoomId;
  final TextEditingController roomSearch;
  final TextEditingController description;
  final MaintenanceSeverity severity;
  final String targetStatus;
  final bool reporting;
  final ValueChanged<String> onRoomSelected;
  final ValueChanged<MaintenanceSeverity> onSeverityChanged;
  final ValueChanged<String> onTargetChanged;
  final VoidCallback onSubmit;

  @override
  State<_ReportIssueCard> createState() => _ReportIssueCardState();
}

class _ReportIssueCardState extends State<_ReportIssueCard> {
  @override
  void initState() {
    super.initState();
    widget.roomSearch.addListener(_refreshSearch);
  }

  @override
  void didUpdateWidget(covariant _ReportIssueCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roomSearch != widget.roomSearch) {
      oldWidget.roomSearch.removeListener(_refreshSearch);
      widget.roomSearch.addListener(_refreshSearch);
    }
  }

  @override
  void dispose() {
    widget.roomSearch.removeListener(_refreshSearch);
    super.dispose();
  }

  void _refreshSearch() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchTerm = widget.roomSearch.text.trim().toLowerCase();
    final roomOptions = widget.rooms
        .where((room) {
          if (searchTerm.isEmpty) {
            return true;
          }

          return room.roomNumber.toLowerCase().contains(searchTerm) ||
              room.status.toLowerCase().contains(searchTerm);
        })
        .take(12)
        .toList(growable: false);
    RoomInventoryItem? selectedRoom;
    for (final room in widget.rooms) {
      if (room.id == widget.selectedRoomId) {
        selectedRoom = room;
        break;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: const Icon(
                    Icons.add_alert_rounded,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create maintenance request',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        selectedRoom == null
                            ? 'Choose the affected room before creating a ticket.'
                            : 'Selected room ${selectedRoom.roomNumber} - ${selectedRoom.status}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: widget.roomSearch,
              decoration: const InputDecoration(
                labelText: 'Find room',
                hintText: 'Search by room number or status',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (roomOptions.isEmpty)
              const _EmptyRoomPicker()
            else
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final room in roomOptions)
                    ChoiceChip(
                      label: Text('${room.roomNumber} - ${room.status}'),
                      selected: widget.selectedRoomId == room.id,
                      onSelected: (_) => widget.onRoomSelected(room.id),
                    ),
                ],
              ),
            if (widget.rooms.length > roomOptions.length) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Showing ${roomOptions.length} of ${widget.rooms.length} rooms. Use search to narrow the list.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: widget.description,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Issue description',
                hintText: 'Example: AC leaking water near the window',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<MaintenanceSeverity>(
              initialValue: widget.severity,
              decoration: const InputDecoration(labelText: 'Severity'),
              items: [
                for (final item in MaintenanceSeverity.values)
                  DropdownMenuItem(
                    value: item,
                    child: Text(item.apiValue),
                  ),
              ],
              onChanged: (value) {
                if (value != null) {
                  widget.onSeverityChanged(value);
                }
              },
            ),
            const SizedBox(height: AppSpacing.md),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'Maintenance',
                  label: Text('Maintenance'),
                  icon: Icon(Icons.build_circle_outlined),
                ),
                ButtonSegment(
                  value: 'OutOfService',
                  label: Text('Out of service'),
                  icon: Icon(Icons.block_rounded),
                ),
              ],
              selected: {widget.targetStatus},
              onSelectionChanged: (value) =>
                  widget.onTargetChanged(value.first),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: widget.reporting ? null : widget.onSubmit,
              icon: widget.reporting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.report_problem_rounded),
              label: const Text('Create request'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaintenanceSummary extends StatelessWidget {
  const _MaintenanceSummary({required this.requests});

  final List<MaintenanceRequestItem> requests;

  @override
  Widget build(BuildContext context) {
    final open = requests.where((item) => item.status == 'Open').length;
    final inProgress =
        requests.where((item) => item.status == 'InProgress').length;
    final critical = requests
        .where((item) => item.severity == 'Critical' || item.severity == 'High')
        .length;

    return Row(
      children: [
        Expanded(
          child: _MaintenanceMetricCard(
            label: 'Open',
            value: open.toString(),
            icon: Icons.error_outline_rounded,
            color: AppColors.warning,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _MaintenanceMetricCard(
            label: 'In repair',
            value: inProgress.toString(),
            icon: Icons.engineering_rounded,
            color: AppColors.brand,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _MaintenanceMetricCard(
            label: 'Urgent',
            value: critical.toString(),
            icon: Icons.priority_high_rounded,
            color: AppColors.danger,
          ),
        ),
      ],
    );
  }
}

class _MaintenanceMetricCard extends StatelessWidget {
  const _MaintenanceMetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: AppSpacing.sm),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _MaintenanceStatusFilter extends StatelessWidget {
  const _MaintenanceStatusFilter({
    required this.selectedStatus,
    required this.onChanged,
  });

  final MaintenanceStatus? selectedStatus;
  final ValueChanged<MaintenanceStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: ChoiceChip(
              label: const Text('All requests'),
              selected: selectedStatus == null,
              onSelected: (_) => onChanged(null),
            ),
          ),
          for (final status in const [
            MaintenanceStatus.open,
            MaintenanceStatus.inProgress,
            MaintenanceStatus.resolved,
            MaintenanceStatus.released,
          ])
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: ChoiceChip(
                label: Text(_maintenanceStatusLabel(status.apiValue)),
                selected: selectedStatus == status,
                onSelected: (_) => onChanged(status),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyRoomPicker extends StatelessWidget {
  const _EmptyRoomPicker();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: const Text('No rooms match the current search.'),
    );
  }
}

class _OperationErrorCard extends StatelessWidget {
  const _OperationErrorCard({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(message, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaintenanceRequestList extends StatelessWidget {
  const _MaintenanceRequestList({
    required this.hotelId,
    required this.items,
    required this.pageIndex,
    required this.pageSize,
    required this.onPageChanged,
    required this.onUpdated,
  });

  final String hotelId;
  final List<MaintenanceRequestItem> items;
  final int pageIndex;
  final int pageSize;
  final void Function(int pageIndex, int pageCount) onPageChanged;
  final VoidCallback onUpdated;

  @override
  Widget build(BuildContext context) {
    final pageCount = ((items.length - 1) ~/ pageSize) + 1;
    final safePageIndex = pageIndex.clamp(0, pageCount - 1);
    final start = safePageIndex * pageSize;
    final end = (start + pageSize).clamp(0, items.length);
    final visibleItems = items.sublist(start, end);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Showing ${start + 1}-$end of ${items.length} requests',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            Text(
              'Page ${safePageIndex + 1} of $pageCount',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        for (final item in visibleItems)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _MaintenanceCard(
              hotelId: hotelId,
              item: item,
              onUpdated: onUpdated,
            ),
          ),
        _MaintenancePaginationControls(
          currentPageIndex: safePageIndex,
          pageCount: pageCount,
          onPageChanged: onPageChanged,
        ),
      ],
    );
  }
}

class _MaintenancePaginationControls extends StatelessWidget {
  const _MaintenancePaginationControls({
    required this.currentPageIndex,
    required this.pageCount,
    required this.onPageChanged,
  });

  final int currentPageIndex;
  final int pageCount;
  final void Function(int pageIndex, int pageCount) onPageChanged;

  @override
  Widget build(BuildContext context) {
    if (pageCount <= 1) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        IconButton.outlined(
          tooltip: 'Previous page',
          onPressed: currentPageIndex == 0
              ? null
              : () => onPageChanged(currentPageIndex - 1, pageCount),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Center(
            child: Text(
              '${currentPageIndex + 1} / $pageCount',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        ),
        IconButton.filled(
          tooltip: 'Next page',
          onPressed: currentPageIndex >= pageCount - 1
              ? null
              : () => onPageChanged(currentPageIndex + 1, pageCount),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

class _MaintenanceCard extends ConsumerStatefulWidget {
  const _MaintenanceCard({
    required this.hotelId,
    required this.item,
    required this.onUpdated,
  });

  final String hotelId;
  final MaintenanceRequestItem item;
  final VoidCallback onUpdated;

  @override
  ConsumerState<_MaintenanceCard> createState() => _MaintenanceCardState();
}

class _MaintenanceCardState extends ConsumerState<_MaintenanceCard> {
  bool _loading = false;

  Future<void> _openDetails() async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _MaintenanceRequestSheet(
        hotelId: widget.hotelId,
        item: widget.item,
      ),
    );
    if (changed == true) {
      widget.onUpdated();
    }
  }

  Future<void> _setStatus(
    MaintenanceStatus status, {
    String? resolutionNote,
  }) async {
    setState(() => _loading = true);
    try {
      await ref.read(operationsApiProvider).updateMaintenanceRequestStatus(
            hotelId: widget.hotelId,
            requestId: widget.item.id,
            status: status,
            resolutionNote: resolutionNote,
          );
      widget.onUpdated();
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

  Future<void> _resolve() async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete repair'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Resolution note',
            hintText: 'Describe the repair and verification performed.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                Navigator.of(context).pop(value);
              }
            },
            child: const Text('Resolve'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (note != null && mounted) {
      await _setStatus(MaintenanceStatus.resolved, resolutionNote: note);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final roles = ref.watch(authControllerProvider).userSession?.roles ??
        const <String>[];
    final canRelease =
        roles.contains('HotelManager') || roles.contains('PropertyOwner');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: const Icon(
                    Icons.handyman_rounded,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Room ${item.roomNumber}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'Created ${item.displayCreatedAt}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                _MaintenancePill(
                  label: item.severity,
                  color: _severityColor(item.severity),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(item.description),
            if (item.resolutionNote?.isNotEmpty == true) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Resolution: ${item.resolutionNote}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _MaintenancePill(
                  label: _maintenanceStatusLabel(item.status),
                  color: _statusColor(item.status),
                ),
                _MaintenancePill(
                  label: 'Room ${item.roomStatus}',
                  color: _roomStatusColor(item.roomStatus),
                ),
                _MaintenancePill(
                  label: _shortRoomCode(item.physicalRoomId),
                  color: AppColors.subtleInk,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: _loading ? null : _openDetails,
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Open request'),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_loading)
              const LinearProgressIndicator()
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: item.status == 'Open'
                          ? () => _setStatus(MaintenanceStatus.inProgress)
                          : null,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Start repair'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: item.status == 'InProgress'
                          ? _resolve
                          : item.status == 'Resolved' && canRelease
                              ? () => _setStatus(MaintenanceStatus.released)
                              : null,
                      icon: Icon(
                        item.status == 'Resolved'
                            ? Icons.meeting_room_outlined
                            : Icons.check_circle_outline_rounded,
                      ),
                      label: Text(
                        item.status == 'Resolved'
                            ? canRelease
                                ? 'Inspect & release room'
                                : 'Awaiting manager release'
                            : 'Resolve repair',
                      ),
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

class _MaintenanceRequestSheet extends ConsumerStatefulWidget {
  const _MaintenanceRequestSheet({
    required this.hotelId,
    required this.item,
  });

  final String hotelId;
  final MaintenanceRequestItem item;

  @override
  ConsumerState<_MaintenanceRequestSheet> createState() =>
      _MaintenanceRequestSheetState();
}

class _MaintenanceRequestSheetState
    extends ConsumerState<_MaintenanceRequestSheet> {
  late MaintenanceStatus _status;
  late String? _assigneeId;
  late final TextEditingController _resolutionNote;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _status = MaintenanceStatus.values.firstWhere(
      (status) => status.apiValue == widget.item.status,
      orElse: () => MaintenanceStatus.open,
    );
    _assigneeId = widget.item.assignedToUserAccountId;
    _resolutionNote = TextEditingController(
      text: widget.item.resolutionNote ?? '',
    );
  }

  @override
  void dispose() {
    _resolutionNote.dispose();
    super.dispose();
  }

  List<MaintenanceStatus> get _allowedStatuses {
    return switch (widget.item.status) {
      'Open' => const [
          MaintenanceStatus.open,
          MaintenanceStatus.inProgress,
        ],
      'InProgress' => const [
          MaintenanceStatus.inProgress,
          MaintenanceStatus.resolved,
        ],
      'Resolved' => const [
          MaintenanceStatus.resolved,
          MaintenanceStatus.released,
        ],
      _ => [_status],
    };
  }

  Future<void> _save() async {
    final note = _resolutionNote.text.trim();
    if (_status == MaintenanceStatus.resolved && note.isEmpty) {
      AppErrorPresenter.showSnackBar(
        context,
        'Enter a diagnosis or resolution note.',
      );
      return;
    }

    setState(() => _loading = true);
    try {
      if (_assigneeId != null &&
          _assigneeId != widget.item.assignedToUserAccountId) {
        await ref.read(operationsApiProvider).assignMaintenanceRequest(
              hotelId: widget.hotelId,
              requestId: widget.item.id,
              assignedToUserAccountId: _assigneeId!,
            );
      }
      if (_status.apiValue != widget.item.status) {
        await ref.read(operationsApiProvider).updateMaintenanceRequestStatus(
              hotelId: widget.hotelId,
              requestId: widget.item.id,
              status: _status,
              resolutionNote:
                  _status == MaintenanceStatus.resolved ? note : null,
            );
      }
      if (mounted) {
        Navigator.of(context).pop(true);
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
    final staff = ref.watch(hotelStaffProvider(widget.hotelId));
    final roles = ref.watch(authControllerProvider).userSession?.roles ??
        const <String>[];
    final canRelease =
        roles.contains('HotelManager') || roles.contains('PropertyOwner');
    final statusOptions = _allowedStatuses
        .where(
          (status) => status != MaintenanceStatus.released || canRelease,
        )
        .toList(growable: false);

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        top: AppSpacing.md,
        right: AppSpacing.md,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Maintenance request',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Room ${widget.item.roomNumber}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _MaintenanceDetailRow(
                      label: 'Severity',
                      value: widget.item.severity,
                    ),
                    _MaintenanceDetailRow(
                      label: 'Room status',
                      value: widget.item.roomStatus,
                    ),
                    _MaintenanceDetailRow(
                      label: 'Created',
                      value: widget.item.displayCreatedAt,
                    ),
                    const Divider(),
                    Text(widget.item.description),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<MaintenanceStatus>(
              initialValue: _status,
              decoration: const InputDecoration(
                labelText: 'Current status',
                prefixIcon: Icon(Icons.sync_alt_rounded),
              ),
              items: [
                for (final status in statusOptions)
                  DropdownMenuItem(
                    value: status,
                    child: Text(_maintenanceStatusLabel(status.apiValue)),
                  ),
              ],
              onChanged: _loading
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _status = value);
                      }
                    },
            ),
            const SizedBox(height: AppSpacing.md),
            staff.when(
              data: (items) {
                final maintainers = items
                    .where(
                      (member) =>
                          member.role == 'MaintenanceStaff' &&
                          member.isAssignmentActive,
                    )
                    .toList(growable: false);
                final knownIds =
                    maintainers.map((member) => member.userAccountId).toSet();
                final value =
                    knownIds.contains(_assigneeId) ? _assigneeId : null;
                return DropdownButtonFormField<String?>(
                  initialValue: value,
                  decoration: const InputDecoration(
                    labelText: 'Assignee',
                    prefixIcon: Icon(Icons.engineering_outlined),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Unassigned'),
                    ),
                    for (final member in maintainers)
                      DropdownMenuItem(
                        value: member.userAccountId,
                        child: Text(member.fullName),
                      ),
                  ],
                  onChanged: _loading
                      ? null
                      : (value) => setState(() => _assigneeId = value),
                );
              },
              error: (error, stackTrace) => const Text(
                'Assignee list is unavailable. Status can still be updated.',
              ),
              loading: () => const LinearProgressIndicator(),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _resolutionNote,
              enabled: !_loading,
              maxLength: 500,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: _status == MaintenanceStatus.resolved
                    ? 'Diagnosis / resolution note'
                    : 'Resolution note',
                hintText: 'Describe diagnosis, repair, and verification.',
                alignLabelWithHint: true,
              ),
            ),
            if (widget.item.status == 'Resolved' && !canRelease)
              const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text('Manager approval is required to release room.'),
              ),
            if (_loading)
              const LinearProgressIndicator()
            else
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_rounded),
                label: Text(
                  _status == MaintenanceStatus.released
                      ? 'Release room'
                      : 'Save update',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MaintenanceDetailRow extends StatelessWidget {
  const _MaintenanceDetailRow({
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _EmptyMaintenance extends StatelessWidget {
  const _EmptyMaintenance();
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            const Icon(Icons.verified_rounded, color: AppColors.success),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No open maintenance requests',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _MaintenancePill extends StatelessWidget {
  const _MaintenancePill({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}

String _maintenanceStatusLabel(String status) {
  return switch (status) {
    'Open' => 'Open',
    'InProgress' => 'In progress',
    'Resolved' => 'Resolved',
    'Released' => 'Released',
    'Cancelled' => 'Cancelled',
    _ => status,
  };
}

Color _severityColor(String severity) {
  return switch (severity) {
    'Critical' => AppColors.danger,
    'High' => AppColors.warning,
    'Medium' => AppColors.brand,
    _ => AppColors.success,
  };
}

Color _statusColor(String status) {
  return switch (status) {
    'Open' => AppColors.warning,
    'InProgress' => AppColors.brand,
    'Resolved' => AppColors.success,
    _ => AppColors.subtleInk,
  };
}

Color _roomStatusColor(String status) {
  return switch (status) {
    'Maintenance' => AppColors.warning,
    'OutOfService' => AppColors.danger,
    'Available' => AppColors.success,
    _ => AppColors.subtleInk,
  };
}

String _shortRoomCode(String value) {
  if (value.length <= 8) {
    return value;
  }

  return 'Room ID ${value.substring(0, 8)}';
}
