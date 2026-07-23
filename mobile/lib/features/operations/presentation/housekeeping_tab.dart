import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../shared/widgets/app_error_presenter.dart';
import '../../auth/application/auth_controller.dart';
import '../application/operations_providers.dart';
import '../domain/operations_models.dart';

class HousekeepingTab extends ConsumerStatefulWidget {
  const HousekeepingTab({super.key, required this.hotelId});

  final String hotelId;

  @override
  ConsumerState<HousekeepingTab> createState() => _HousekeepingTabState();
}

class _HousekeepingTabState extends ConsumerState<HousekeepingTab> {
  final _roomFilterController = TextEditingController();
  HousekeepingTaskStatus? _statusFilter;
  String? _taskTypeFilter;

  void _setStatusFilter(HousekeepingTaskStatus? status) {
    setState(() => _statusFilter = status);
  }

  @override
  void dispose() {
    _roomFilterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final request = HousekeepingTasksRequest(hotelId: widget.hotelId);
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
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _roomFilterController,
                  decoration: const InputDecoration(
                    labelText: 'Room filter',
                    hintText: 'Room number',
                    prefixIcon: Icon(Icons.meeting_room_outlined),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: _taskTypeFilter,
                  decoration: const InputDecoration(
                    labelText: 'Task type',
                    prefixIcon: Icon(Icons.checklist_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: null,
                      child: Text('All types'),
                    ),
                    DropdownMenuItem(
                      value: 'CheckoutCleaning',
                      child: Text('Checkout'),
                    ),
                    DropdownMenuItem(
                      value: 'DeepCleaning',
                      child: Text('Deep clean'),
                    ),
                    DropdownMenuItem(
                      value: 'Inspection',
                      child: Text('Inspection'),
                    ),
                  ],
                  onChanged: (value) => setState(() => _taskTypeFilter = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          tasks.when(
            data: (items) {
              final roomTerm = _roomFilterController.text.trim().toLowerCase();
              final visibleItems = items.where((task) {
                final matchesStatus = _statusFilter == null ||
                    task.status == _statusFilter!.apiValue;
                final matchesRoom = roomTerm.isEmpty ||
                    task.roomNumber.toLowerCase().contains(roomTerm);
                final matchesType =
                    _taskTypeFilter == null || task.taskType == _taskTypeFilter;
                return matchesStatus && matchesRoom && matchesType;
              }).toList(growable: false);

              if (visibleItems.isEmpty) {
                return const _EmptyTasks();
              }

              return Column(
                children: [
                  for (final task in visibleItems)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _HousekeepingTaskCard(
                        hotelId: widget.hotelId,
                        task: task,
                        onUpdated: () =>
                            ref.invalidate(housekeepingTasksProvider(request)),
                      ),
                    ),
                ],
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
    final dirty = tasks.where((task) => task.roomStatus == 'Dirty').length;
    final inProgress =
        tasks.where((task) => task.status == 'InProgress').length;
    final inspection =
        tasks.where((task) => task.status == 'InspectionRequired').length;
    final completed = tasks.where((task) => task.status == 'Completed').length;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: 1.55,
      children: [
        _HousekeepingMetricCard(
          label: 'Dirty',
          value: dirty.toString(),
          icon: Icons.schedule_rounded,
          color: AppColors.warning,
        ),
        _HousekeepingMetricCard(
          label: 'Cleaning',
          value: inProgress.toString(),
          icon: Icons.cleaning_services_rounded,
          color: AppColors.brand,
        ),
        _HousekeepingMetricCard(
          label: 'Inspection',
          value: inspection.toString(),
          icon: Icons.fact_check_outlined,
          color: AppColors.warning,
        ),
        _HousekeepingMetricCard(
          label: 'Completed',
          value: completed.toString(),
          icon: Icons.check_circle_outline_rounded,
          color: AppColors.success,
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
            HousekeepingTaskStatus.inspectionRequired,
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

class _HousekeepingTaskCard extends StatelessWidget {
  const _HousekeepingTaskCard({
    required this.hotelId,
    required this.task,
    required this.onUpdated,
  });

  final String hotelId;
  final HousekeepingTask task;
  final VoidCallback onUpdated;

  Future<void> _openDetails(BuildContext context) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _HousekeepingTaskSheet(
        hotelId: hotelId,
        task: task,
      ),
    );
    if (changed == true) {
      onUpdated();
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _housekeepingStatusColor(task.status);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openDetails(context),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
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
                    Text(_taskTypeLabel(task.taskType)),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        _TaskPill(
                          label: _taskStatusLabel(task.status),
                          color: statusColor,
                        ),
                        _TaskPill(
                          label: task.roomStatus,
                          color: _roomStatusColor(task.roomStatus),
                        ),
                        _TaskPill(
                          label: task.isAssigned ? 'Assigned' : 'Unassigned',
                          color: task.isAssigned
                              ? AppColors.brand
                              : AppColors.warning,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Open task',
                onPressed: () => _openDetails(context),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HousekeepingTaskSheet extends ConsumerStatefulWidget {
  const _HousekeepingTaskSheet({
    required this.hotelId,
    required this.task,
  });

  final String hotelId;
  final HousekeepingTask task;

  @override
  ConsumerState<_HousekeepingTaskSheet> createState() =>
      _HousekeepingTaskSheetState();
}

class _HousekeepingTaskSheetState
    extends ConsumerState<_HousekeepingTaskSheet> {
  bool _loading = false;

  Future<void> _setStatus(HousekeepingTaskStatus status) async {
    setState(() => _loading = true);
    try {
      final session = ref.read(authControllerProvider).userSession;
      if (!widget.task.isAssigned &&
          session != null &&
          session.roles.contains('HousekeepingStaff')) {
        await ref.read(operationsApiProvider).assignHousekeepingTask(
              hotelId: widget.hotelId,
              taskId: widget.task.id,
              assignedToUserAccountId: session.userId,
            );
      }
      await ref.read(operationsApiProvider).updateHousekeepingTaskStatus(
            hotelId: widget.hotelId,
            taskId: widget.task.id,
            status: status,
          );
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

  Future<void> _completeInspection() async {
    setState(() => _loading = true);
    try {
      await ref.read(operationsApiProvider).completeHousekeepingInspection(
            hotelId: widget.hotelId,
            taskId: widget.task.id,
          );
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

  Future<void> _reportIssue() async {
    final reported = await showDialog<bool>(
      context: context,
      builder: (context) => _HousekeepingIssueDialog(
        hotelId: widget.hotelId,
        task: widget.task,
      ),
    );
    if (reported == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final roles = ref.watch(authControllerProvider).userSession?.roles ??
        const <String>[];
    final canInspect =
        roles.contains('HotelManager') || roles.contains('PropertyOwner');

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
                    'Housekeeping task',
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
                      'Room ${task.roomNumber}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _HousekeepingDetailRow(
                      label: 'Task type',
                      value: _taskTypeLabel(task.taskType),
                    ),
                    _HousekeepingDetailRow(
                      label: 'Cleaning status',
                      value: _taskStatusLabel(task.status),
                    ),
                    _HousekeepingDetailRow(
                      label: 'Room status',
                      value: task.roomStatus,
                    ),
                    _HousekeepingDetailRow(
                      label: 'Assignment',
                      value: task.isAssigned ? 'Assigned' : 'Unassigned',
                    ),
                    if (task.bookingId != null)
                      _HousekeepingDetailRow(
                        label: 'Booking',
                        value: _shortCode(task.bookingId!, 'Booking'),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: _loading ? null : _reportIssue,
              icon: const Icon(Icons.report_problem_outlined),
              label: const Text('Report room issue'),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_loading)
              const LinearProgressIndicator()
            else if (task.status == 'Open')
              FilledButton.icon(
                onPressed: () => _setStatus(HousekeepingTaskStatus.inProgress),
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(task.isAssigned ? 'Start cleaning' : 'Claim task'),
              )
            else if (task.status == 'InProgress')
              FilledButton.icon(
                onPressed: () => _setStatus(HousekeepingTaskStatus.completed),
                icon: const Icon(Icons.check_rounded),
                label: const Text('Mark cleaning complete'),
              )
            else if (task.status == 'InspectionRequired')
              FilledButton.icon(
                onPressed: canInspect ? _completeInspection : null,
                icon: const Icon(Icons.fact_check_outlined),
                label: Text(
                  canInspect
                      ? 'Complete inspection'
                      : 'Manager inspection required',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HousekeepingIssueDialog extends ConsumerStatefulWidget {
  const _HousekeepingIssueDialog({
    required this.hotelId,
    required this.task,
  });

  final String hotelId;
  final HousekeepingTask task;

  @override
  ConsumerState<_HousekeepingIssueDialog> createState() =>
      _HousekeepingIssueDialogState();
}

class _HousekeepingIssueDialogState
    extends ConsumerState<_HousekeepingIssueDialog> {
  final _description = TextEditingController();
  MaintenanceSeverity _severity = MaintenanceSeverity.medium;
  String _targetRoomStatus = 'Maintenance';
  bool _loading = false;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final description = _description.text.trim();
    if (description.isEmpty) {
      AppErrorPresenter.showSnackBar(context, 'Enter issue details.');
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(operationsApiProvider).reportMaintenanceIssue(
            hotelId: widget.hotelId,
            physicalRoomId: widget.task.physicalRoomId,
            description: description,
            severity: _severity,
            targetRoomStatus: _targetRoomStatus,
          );
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
    return AlertDialog(
      title: Text('Report issue: room ${widget.task.roomNumber}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _description,
              maxLength: 500,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Issue description',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<MaintenanceSeverity>(
              initialValue: _severity,
              decoration: const InputDecoration(labelText: 'Severity'),
              items: [
                for (final severity in MaintenanceSeverity.values)
                  DropdownMenuItem(
                    value: severity,
                    child: Text(severity.apiValue),
                  ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _severity = value);
                }
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String>(
              initialValue: _targetRoomStatus,
              decoration: const InputDecoration(labelText: 'Room impact'),
              items: const [
                DropdownMenuItem(
                  value: 'Maintenance',
                  child: Text('Maintenance'),
                ),
                DropdownMenuItem(
                  value: 'OutOfService',
                  child: Text('Out of service'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _targetRoomStatus = value);
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _loading ? null : _submit,
          icon: _loading
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.report_problem_rounded),
          label: const Text('Create request'),
        ),
      ],
    );
  }
}

class _HousekeepingDetailRow extends StatelessWidget {
  const _HousekeepingDetailRow({
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
            width: 116,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _EmptyTasks extends StatelessWidget {
  const _EmptyTasks();
  @override
  Widget build(BuildContext context) {
    return Card(
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
              'No housekeeping tasks match the filters',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
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
    'InspectionRequired' => 'Inspection required',
    'Completed' => 'Completed',
    'Cancelled' => 'Cancelled',
    _ => status,
  };
}

Color _housekeepingStatusColor(String status) {
  return switch (status) {
    'Open' => AppColors.warning,
    'InProgress' => AppColors.brand,
    'InspectionRequired' => AppColors.warning,
    'Completed' => AppColors.success,
    _ => AppColors.subtleInk,
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
    return Card(
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
    );
  }
}
