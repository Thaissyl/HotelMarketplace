import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../shared/widgets/app_error_presenter.dart';
import '../application/operations_providers.dart';
import '../domain/operations_models.dart';

class HousekeepingTab extends ConsumerWidget {
  const HousekeepingTab({super.key, required this.hotelId});

  final String hotelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = HousekeepingTasksRequest(hotelId: hotelId);
    final tasks = ref.watch(housekeepingTasksProvider(request));

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(housekeepingTasksProvider(request)),
      child: tasks.when(
        data: (items) {
          if (items.isEmpty) {
            return const _EmptyTasks();
          }

          return GridView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 360,
              childAspectRatio: 1.25,
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.md,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              return _HousekeepingTaskCard(
                hotelId: hotelId,
                task: items[index],
                onUpdated: () =>
                    ref.invalidate(housekeepingTasksProvider(request)),
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
                  child: Text(
                    'Room ${task.roomNumber}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text('${task.taskType} · ${task.status}'),
            Text('Room status: ${task.roomStatus}'),
            const Spacer(),
            if (_loading)
              const LinearProgressIndicator()
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: task.status == 'Open'
                          ? () => _setStatus(HousekeepingTaskStatus.inProgress)
                          : null,
                      child: const Text('Start'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: task.status == 'InProgress'
                          ? () => _setStatus(HousekeepingTaskStatus.completed)
                          : null,
                      child: const Text('Done'),
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
