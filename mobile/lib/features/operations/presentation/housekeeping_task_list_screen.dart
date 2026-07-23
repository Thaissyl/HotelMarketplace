import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../shared/widgets/srs_screen.dart';
import '../application/operations_providers.dart';
import '../domain/operations_models.dart';
import 'housekeeping_task_detail_screen.dart';
import 'housekeeping_task_ui.dart';

class HousekeepingTaskListScreen extends ConsumerStatefulWidget {
  const HousekeepingTaskListScreen({super.key, required this.hotelId});

  final String hotelId;

  @override
  ConsumerState<HousekeepingTaskListScreen> createState() =>
      _HousekeepingTaskListScreenState();
}

class _HousekeepingTaskListScreenState
    extends ConsumerState<HousekeepingTaskListScreen> {
  String? _status;
  String? _priority;
  String? _roomNumber;

  HousekeepingTasksRequest get _request =>
      HousekeepingTasksRequest(hotelId: widget.hotelId);

  Future<void> _refresh() async {
    ref.invalidate(housekeepingTasksProvider(_request));
    ref.invalidate(
      physicalRoomsProvider(PhysicalRoomsRequest(hotelId: widget.hotelId)),
    );
    await ref.read(housekeepingTasksProvider(_request).future);
  }

  Future<void> _openTask(HousekeepingTask task) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => HousekeepingTaskDetailScreen(
          hotelId: widget.hotelId,
          task: task,
        ),
      ),
    );
    if (changed == true) {
      ref.invalidate(housekeepingTasksProvider(_request));
      ref.invalidate(
        physicalRoomsProvider(PhysicalRoomsRequest(hotelId: widget.hotelId)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(housekeepingTasksProvider(_request));

    return SrsScreen(
      title: 'Housekeeping Task List Screen',
      scrollable: false,
      padding: EdgeInsets.zero,
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: tasks.when(
          data: (items) {
            final rooms = items
                .map((task) => task.roomNumber)
                .where((room) => room.isNotEmpty)
                .toSet()
                .toList()
              ..sort();
            final visible = items.where((task) {
              final statusMatches = _status == null || task.status == _status;
              final priorityMatches = _priority == null ||
                  housekeepingTaskPriority(task) == _priority;
              final roomMatches =
                  _roomNumber == null || task.roomNumber == _roomNumber;
              return statusMatches && priorityMatches && roomMatches;
            }).toList(growable: false);

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.xl),
              children: [
                _TaskFilters(
                  status: _status,
                  priority: _priority,
                  roomNumber: _roomNumber,
                  rooms: rooms,
                  onStatusChanged: (value) => setState(() => _status = value),
                  onPriorityChanged: (value) =>
                      setState(() => _priority = value),
                  onRoomChanged: (value) => setState(() => _roomNumber = value),
                ),
                const SizedBox(height: AppSpacing.xxl),
                const SrsSectionTitle('Task List'),
                const SizedBox(height: AppSpacing.md),
                if (visible.isEmpty)
                  const SrsPanel(
                    child: Text(
                      'No housekeeping tasks match the selected filters.',
                    ),
                  )
                else
                  for (final task in visible) ...[
                    _TaskListCard(
                      task: task,
                      onOpen: () => _openTask(task),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
              ],
            );
          },
          error: (error, stackTrace) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              SrsPanel(
                child: Column(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.danger),
                    const SizedBox(height: AppSpacing.sm),
                    const Text('Unable to load housekeeping tasks.'),
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton(
                      onPressed: _refresh,
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}

class _TaskFilters extends StatelessWidget {
  const _TaskFilters({
    required this.status,
    required this.priority,
    required this.roomNumber,
    required this.rooms,
    required this.onStatusChanged,
    required this.onPriorityChanged,
    required this.onRoomChanged,
  });

  final String? status;
  final String? priority;
  final String? roomNumber;
  final List<String> rooms;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onPriorityChanged;
  final ValueChanged<String?> onRoomChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: DropdownButtonFormField<String?>(
            initialValue: status,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Status Filter',
              prefixIcon: Icon(Icons.filter_list),
            ),
            items: const [
              DropdownMenuItem(value: null, child: Text('All Status')),
              DropdownMenuItem(value: 'Open', child: Text('Dirty')),
              DropdownMenuItem(
                value: 'InProgress',
                child: Text('Cleaning'),
              ),
              DropdownMenuItem(
                value: 'InspectionRequired',
                child: Text('Inspection'),
              ),
              DropdownMenuItem(value: 'Completed', child: Text('Cleaned')),
            ],
            onChanged: onStatusChanged,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: DropdownButtonFormField<String?>(
            initialValue: priority,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Priority Filter',
              prefixIcon: Icon(Icons.outlined_flag),
            ),
            items: const [
              DropdownMenuItem(value: null, child: Text('All Priorities')),
              DropdownMenuItem(value: 'High', child: Text('High')),
              DropdownMenuItem(value: 'Medium', child: Text('Medium')),
              DropdownMenuItem(value: 'Low', child: Text('Low')),
            ],
            onChanged: onPriorityChanged,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: DropdownButtonFormField<String?>(
            initialValue: roomNumber,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Room Filter',
              prefixIcon: Icon(Icons.meeting_room_outlined),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('All Rooms')),
              for (final room in rooms)
                DropdownMenuItem(value: room, child: Text('Room $room')),
            ],
            onChanged: onRoomChanged,
          ),
        ),
      ],
    );
  }
}

class _TaskListCard extends StatelessWidget {
  const _TaskListCard({required this.task, required this.onOpen});

  final HousekeepingTask task;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return SrsPanel(
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.surfaceSoft,
            foregroundColor: AppColors.ink,
            child: Icon(housekeepingTaskIcon(task)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Room ${task.roomNumber}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    _SmallTag(
                      label:
                          'Status  ${housekeepingTaskStatusLabel(task.status)}',
                    ),
                    _SmallTag(
                      label: 'Priority  ${housekeepingTaskPriority(task)}',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.assignment_outlined),
            label: const Text('Open Task'),
          ),
        ],
      ),
    );
  }
}

class _SmallTag extends StatelessWidget {
  const _SmallTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.outlineSoft),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
