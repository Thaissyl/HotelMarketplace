import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../shared/widgets/srs_screen.dart';
import '../../auth/application/auth_controller.dart';
import '../application/operations_providers.dart';
import '../domain/operations_models.dart';
import 'housekeeping_task_detail_screen.dart';
import 'housekeeping_task_list_screen.dart';
import 'housekeeping_task_ui.dart';
import 'room_status_board.dart';

class HousekeepingTab extends ConsumerWidget {
  const HousekeepingTab({super.key, required this.hotelId});

  final String hotelId;

  HousekeepingTasksRequest get _taskRequest =>
      HousekeepingTasksRequest(hotelId: hotelId);

  PhysicalRoomsRequest get _roomRequest =>
      PhysicalRoomsRequest(hotelId: hotelId);

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(housekeepingTasksProvider(_taskRequest));
    ref.invalidate(physicalRoomsProvider(_roomRequest));
    ref.invalidate(roomTypesProvider(hotelId));
    await Future.wait([
      ref.read(housekeepingTasksProvider(_taskRequest).future),
      ref.read(physicalRoomsProvider(_roomRequest).future),
    ]);
  }

  Future<void> _openTaskList(BuildContext context, WidgetRef ref) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => HousekeepingTaskListScreen(hotelId: hotelId),
      ),
    );
    if (changed == true) {
      ref.invalidate(housekeepingTasksProvider(_taskRequest));
      ref.invalidate(physicalRoomsProvider(_roomRequest));
    }
  }

  Future<void> _openTask(
    BuildContext context,
    WidgetRef ref,
    HousekeepingTask task,
  ) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => HousekeepingTaskDetailScreen(
          hotelId: hotelId,
          task: task,
        ),
      ),
    );
    if (changed == true) {
      ref.invalidate(housekeepingTasksProvider(_taskRequest));
      ref.invalidate(physicalRoomsProvider(_roomRequest));
    }
  }

  Future<void> _openRoomStatusBoard(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => RoomStatusBoard(hotelId: hotelId),
      ),
    );
    ref.invalidate(physicalRoomsProvider(_roomRequest));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(housekeepingTasksProvider(_taskRequest));
    final rooms = ref.watch(physicalRoomsProvider(_roomRequest));

    return RefreshIndicator(
      onRefresh: () => _refresh(ref),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          const SrsSectionTitle('Task Count Summary'),
          const SizedBox(height: AppSpacing.md),
          tasks.when(
            data: (taskItems) => rooms.when(
              data: (roomItems) => _TaskCountSummary(
                tasks: taskItems,
                rooms: roomItems,
              ),
              error: (error, stackTrace) =>
                  const _InlineError(message: 'Unable to load room counts.'),
              loading: () => const LinearProgressIndicator(),
            ),
            error: (error, stackTrace) =>
                const _InlineError(message: 'Unable to load task counts.'),
            loading: () => const LinearProgressIndicator(),
          ),
          const SizedBox(height: AppSpacing.xxl),
          const SrsSectionTitle('Assigned Tasks Preview'),
          const SizedBox(height: AppSpacing.md),
          tasks.when(
            data: (items) {
              final userId =
                  ref.watch(authControllerProvider).userSession?.userId;
              final assigned = items
                  .where((task) => task.assignedToUserAccountId == userId)
                  .toList(growable: false);
              final preview = (assigned.isNotEmpty
                      ? assigned
                      : items.where((task) => task.status != 'Completed'))
                  .take(3)
                  .toList(growable: false);
              return _AssignedTaskPreview(
                tasks: preview,
                onOpen: (task) => _openTask(context, ref, task),
              );
            },
            error: (error, stackTrace) => const _InlineError(
              message: 'Unable to load assigned housekeeping tasks.',
            ),
            loading: () => const _PreviewLoading(),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Row(
            children: [
              const Expanded(child: SrsSectionTitle('Room Status Summary')),
              TextButton(
                onPressed: () => _openRoomStatusBoard(context, ref),
                child: const Text('View Board'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          rooms.when(
            data: (items) => _RoomStatusSummary(rooms: items),
            error: (error, stackTrace) => const _InlineError(
              message: 'Unable to load room status summary.',
            ),
            loading: () => const LinearProgressIndicator(),
          ),
          const SizedBox(height: AppSpacing.xxl),
          const SrsFieldLabel('Open Task List'),
          OutlinedButton.icon(
            onPressed: () => _openTaskList(context, ref),
            icon: const Icon(Icons.assignment_outlined),
            label: const Text('Open Task List'),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _TaskCountSummary extends StatelessWidget {
  const _TaskCountSummary({required this.tasks, required this.rooms});

  final List<HousekeepingTask> tasks;
  final List<RoomInventoryItem> rooms;

  @override
  Widget build(BuildContext context) {
    final urgent = tasks.where((task) {
      final age = DateTime.now().toUtc().difference(task.createdAtUtc);
      return task.status == 'Open' &&
          (!task.isAssigned || age >= const Duration(hours: 2));
    }).length;
    final metrics = [
      (
        label: 'Dirty',
        value: rooms.where((room) => room.status == 'Dirty').length,
        icon: Icons.bed_outlined,
      ),
      (
        label: 'Cleaning',
        value: rooms.where((room) => room.status == 'Cleaning').length,
        icon: Icons.cleaning_services_outlined,
      ),
      (
        label: 'Inspection',
        value:
            rooms.where((room) => room.status == 'InspectionRequired').length,
        icon: Icons.assignment_turned_in_outlined,
      ),
      (
        label: 'Urgent',
        value: urgent,
        icon: Icons.warning_amber_rounded,
      ),
    ];

    return Row(
      children: [
        for (var index = 0; index < metrics.length; index++) ...[
          Expanded(
            child: _MetricTile(
              label: metrics[index].label,
              value: metrics[index].value,
              icon: metrics[index].icon,
            ),
          ),
          if (index < metrics.length - 1) const SizedBox(width: AppSpacing.xs),
        ],
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SrsPanel(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.md,
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.surfaceSoft,
            foregroundColor: AppColors.ink,
            child: Icon(icon),
          ),
          const SizedBox(height: AppSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value.toString(),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ],
      ),
    );
  }
}

class _AssignedTaskPreview extends StatelessWidget {
  const _AssignedTaskPreview({required this.tasks, required this.onOpen});

  final List<HousekeepingTask> tasks;
  final ValueChanged<HousekeepingTask> onOpen;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const SrsPanel(
        child: Text('No active housekeeping tasks are assigned.'),
      );
    }

    return SrsPanel(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Column(
        children: [
          for (var index = 0; index < tasks.length; index++) ...[
            InkWell(
              onTap: () => onOpen(tasks[index]),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: AppColors.surfaceSoft,
                      foregroundColor: AppColors.ink,
                      child: Icon(Icons.meeting_room_outlined),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        'Room ${tasks[index].roomNumber}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    _OutlineTag(
                      text:
                          'Priority: ${housekeepingTaskPriority(tasks[index])}',
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    _OutlineTag(
                      text:
                          'Status: ${housekeepingTaskStatusLabel(tasks[index].status)}',
                    ),
                  ],
                ),
              ),
            ),
            if (index < tasks.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _RoomStatusSummary extends StatelessWidget {
  const _RoomStatusSummary({required this.rooms});

  final List<RoomInventoryItem> rooms;

  @override
  Widget build(BuildContext context) {
    final total = rooms.isEmpty ? 1 : rooms.length;
    final summaries = [
      (
        label: 'Dirty',
        count: rooms.where((room) => room.status == 'Dirty').length,
        icon: Icons.bed_outlined,
      ),
      (
        label: 'Cleaning',
        count: rooms.where((room) => room.status == 'Cleaning').length,
        icon: Icons.cleaning_services_outlined,
      ),
      (
        label: 'Available',
        count: rooms.where((room) => room.status == 'Available').length,
        icon: Icons.meeting_room_outlined,
      ),
    ];

    return SrsPanel(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Column(
        children: [
          for (var index = 0; index < summaries.length; index++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.surfaceSoft,
                    foregroundColor: AppColors.ink,
                    child: Icon(summaries[index].icon, size: 20),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  SizedBox(
                    width: 78,
                    child: Text(summaries[index].label),
                  ),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: summaries[index].count / total,
                      minHeight: 8,
                      color: AppColors.brand,
                      backgroundColor: AppColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  SizedBox(
                    width: 70,
                    child: Text(
                      '${summaries[index].count} '
                      '(${(summaries[index].count / total * 100).round()}%)',
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
            if (index < summaries.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _OutlineTag extends StatelessWidget {
  const _OutlineTag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.outline),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall,
        maxLines: 1,
      ),
    );
  }
}

class _PreviewLoading extends StatelessWidget {
  const _PreviewLoading();

  @override
  Widget build(BuildContext context) {
    return const SrsPanel(child: LinearProgressIndicator());
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return SrsPanel(
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}
