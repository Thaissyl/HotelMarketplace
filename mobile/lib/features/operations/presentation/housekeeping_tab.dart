import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../shared/widgets/app_error_presenter.dart';
import '../application/operations_providers.dart';
import '../domain/operations_models.dart';

class HousekeepingTab extends ConsumerStatefulWidget {
  const HousekeepingTab({super.key, required this.hotelId});

  final String hotelId;

  @override
  ConsumerState<HousekeepingTab> createState() => _HousekeepingTabState();
}

class _HousekeepingTabState extends ConsumerState<HousekeepingTab> {
  HousekeepingTaskStatus? _statusFilter;

  void _setStatusFilter(HousekeepingTaskStatus? status) {
    setState(() => _statusFilter = status);
  }

  @override
  Widget build(BuildContext context) {
    final request = HousekeepingTasksRequest(
      hotelId: widget.hotelId,
      status: _statusFilter,
    );
    final tasks = ref.watch(housekeepingTasksProvider(request));

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(housekeepingTasksProvider(request)),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            'Housekeeping board',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Claim room-cleaning tasks, mark rooms clean, and return rooms to available inventory.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          tasks.when(
            data: (items) => _HousekeepingSummary(tasks: items),
            error: (error, stackTrace) => const SizedBox.shrink(),
            loading: () => const LinearProgressIndicator(),
          ),
          const SizedBox(height: AppSpacing.md),
          _HousekeepingStatusFilter(
            selectedStatus: _statusFilter,
            onChanged: _setStatusFilter,
          ),
          const SizedBox(height: AppSpacing.md),
          tasks.when(
            data: (items) {
              if (items.isEmpty) {
                return const _EmptyTasks();
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 720 ? 2 : 1;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      childAspectRatio: columns == 1 ? 1.35 : 1.15,
                      crossAxisSpacing: AppSpacing.md,
                      mainAxisSpacing: AppSpacing.md,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      return _HousekeepingTaskCard(
                        hotelId: widget.hotelId,
                        task: items[index],
                        onUpdated: () =>
                            ref.invalidate(housekeepingTasksProvider(request)),
                      );
                    },
                  );
                },
              );
            },
            error: (error, stackTrace) => _ErrorList(
              message: 'Unable to load housekeeping tasks.',
              onRetry: () => ref.invalidate(housekeepingTasksProvider(request)),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
    );
  }
}

class _HousekeepingSummary extends StatelessWidget {
  const _HousekeepingSummary({required this.tasks});

  final List<HousekeepingTask> tasks;

  @override
  Widget build(BuildContext context) {
    final open = tasks.where((task) => task.status == 'Open').length;
    final inProgress =
        tasks.where((task) => task.status == 'InProgress').length;
    final completed = tasks.where((task) => task.status == 'Completed').length;

    return Row(
      children: [
        Expanded(
          child: _HousekeepingMetricCard(
            label: 'Waiting',
            value: open.toString(),
            icon: Icons.schedule_rounded,
            color: AppColors.warning,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _HousekeepingMetricCard(
            label: 'Cleaning',
            value: inProgress.toString(),
            icon: Icons.cleaning_services_rounded,
            color: AppColors.brand,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _HousekeepingMetricCard(
            label: 'Done',
            value: completed.toString(),
            icon: Icons.check_circle_outline_rounded,
            color: AppColors.success,
          ),
        ),
      ],
    );
  }
}

class _HousekeepingMetricCard extends StatelessWidget {
  const _HousekeepingMetricCard({
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

class _HousekeepingStatusFilter extends StatelessWidget {
  const _HousekeepingStatusFilter({
    required this.selectedStatus,
    required this.onChanged,
  });

  final HousekeepingTaskStatus? selectedStatus;
  final ValueChanged<HousekeepingTaskStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: ChoiceChip(
              label: const Text('All tasks'),
              selected: selectedStatus == null,
              onSelected: (_) => onChanged(null),
            ),
          ),
          for (final status in const [
            HousekeepingTaskStatus.open,
            HousekeepingTaskStatus.inProgress,
            HousekeepingTaskStatus.completed,
          ])
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: ChoiceChip(
                label: Text(_taskStatusLabel(status.apiValue)),
                selected: selectedStatus == status,
                onSelected: (_) => onChanged(status),
              ),
            ),
        ],
      ),
    );
  }
}

class _HousekeepingTaskCard extends ConsumerStatefulWidget {
  const _HousekeepingTaskCard({
    required this.hotelId,
    required this.task,
    required this.onUpdated,
  });

  final String hotelId;
  final HousekeepingTask task;
  final VoidCallback onUpdated;

  @override
  ConsumerState<_HousekeepingTaskCard> createState() =>
      _HousekeepingTaskCardState();
}

class _HousekeepingTaskCardState extends ConsumerState<_HousekeepingTaskCard> {
  bool _loading = false;

  Future<void> _setStatus(HousekeepingTaskStatus status) async {
    setState(() => _loading = true);
    try {
      await ref.read(operationsApiProvider).updateHousekeepingTaskStatus(
            hotelId: widget.hotelId,
            taskId: widget.task.id,
            status: status,
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

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final statusColor = _statusColor(task.status);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: Icon(Icons.meeting_room_rounded, color: statusColor),
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
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        _taskTypeLabel(task.taskType),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                _TaskPill(
                  label: _taskStatusLabel(task.status),
                  color: statusColor,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _TaskPill(
                  label: 'Room ${task.roomStatus}',
                  color: _roomStatusColor(task.roomStatus),
                ),
                _TaskPill(
                  label: task.isAssigned ? 'Assigned to me' : 'Unclaimed',
                  color: task.isAssigned ? AppColors.brand : AppColors.warning,
                ),
                if (task.bookingId != null)
                  _TaskPill(
                    label: _shortCode(task.bookingId!, 'Booking'),
                    color: AppColors.subtleInk,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              task.status == 'Open'
                  ? 'Claim this task when you start cleaning the room.'
                  : task.status == 'InProgress'
                      ? 'Mark clean after the room is ready for guests.'
                      : 'Room cleaning has been completed.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Spacer(),
            if (_loading)
              const LinearProgressIndicator()
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: task.status == 'Open'
                          ? () => _setStatus(HousekeepingTaskStatus.inProgress)
                          : null,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Claim'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: task.status == 'InProgress'
                          ? () => _setStatus(HousekeepingTaskStatus.completed)
                          : null,
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Mark clean'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    return switch (status) {
      'Open' => AppColors.warning,
      'InProgress' => AppColors.brand,
      'Completed' => AppColors.success,
      _ => AppColors.subtleInk,
    };
  }
}

class _EmptyTasks extends StatelessWidget {
  const _EmptyTasks();
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'No housekeeping tasks',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TaskPill extends StatelessWidget {
  const _TaskPill({
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

String _taskStatusLabel(String status) {
  return switch (status) {
    'Open' => 'Waiting',
    'InProgress' => 'Cleaning',
    'Completed' => 'Completed',
    'Cancelled' => 'Cancelled',
    _ => status,
  };
}

String _taskTypeLabel(String taskType) {
  return switch (taskType) {
    'CheckoutCleaning' => 'Checkout cleaning',
    'DeepCleaning' => 'Deep cleaning',
    'Inspection' => 'Room inspection',
    _ => taskType,
  };
}

Color _roomStatusColor(String status) {
  return switch (status) {
    'Dirty' => AppColors.warning,
    'Cleaning' => AppColors.brand,
    'Available' => AppColors.success,
    _ => AppColors.subtleInk,
  };
}

String _shortCode(String value, String prefix) {
  if (value.length <= 8) {
    return '$prefix $value';
  }

  return '$prefix ${value.substring(0, 8)}';
}

class _ErrorList extends StatelessWidget {
  const _ErrorList({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              children: [
                Text(message),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
