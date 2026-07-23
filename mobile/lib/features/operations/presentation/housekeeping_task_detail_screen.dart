import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../shared/utils/app_formatters.dart';
import '../../../shared/widgets/app_error_presenter.dart';
import '../../../shared/widgets/srs_screen.dart';
import '../../auth/application/auth_controller.dart';
import '../application/operations_providers.dart';
import '../domain/operations_models.dart';
import 'housekeeping_task_ui.dart';

class HousekeepingTaskDetailScreen extends ConsumerStatefulWidget {
  const HousekeepingTaskDetailScreen({
    super.key,
    required this.hotelId,
    required this.task,
  });

  final String hotelId;
  final HousekeepingTask task;

  @override
  ConsumerState<HousekeepingTaskDetailScreen> createState() =>
      _HousekeepingTaskDetailScreenState();
}

class _HousekeepingTaskDetailScreenState
    extends ConsumerState<HousekeepingTaskDetailScreen> {
  static const _checklistLabels = [
    'Strip bed and replace linens',
    'Replace towels',
    'Empty trash',
    'Clean bathroom and disinfect fixtures',
    'Vacuum and mop floors',
    'Dust all surfaces and furniture',
    'Final inspection',
  ];

  late HousekeepingTaskStatus _selectedStatus;
  final _notesController = TextEditingController();
  late final List<bool> _checklist;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedStatus = HousekeepingTaskStatus.values.firstWhere(
      (status) => status.apiValue == widget.task.status,
      orElse: () => HousekeepingTaskStatus.open,
    );
    final cleaningAlreadyCompleted =
        widget.task.status == 'InspectionRequired' ||
            widget.task.status == 'Completed';
    _checklist = List<bool>.filled(
      _checklistLabels.length,
      cleaningAlreadyCompleted,
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  List<HousekeepingTaskStatus> get _availableStatuses {
    final roles =
        ref.read(authControllerProvider).userSession?.roles ?? const <String>[];
    final canInspect =
        roles.contains('HotelManager') || roles.contains('PropertyOwner');
    return switch (widget.task.status) {
      'Open' => const [
          HousekeepingTaskStatus.open,
          HousekeepingTaskStatus.inProgress,
        ],
      'InProgress' => const [
          HousekeepingTaskStatus.inProgress,
          HousekeepingTaskStatus.completed,
        ],
      'InspectionRequired' => [
          HousekeepingTaskStatus.inspectionRequired,
          if (canInspect) HousekeepingTaskStatus.completed,
        ],
      'Completed' => const [HousekeepingTaskStatus.completed],
      _ => [_selectedStatus],
    };
  }

  bool get _isCompleting {
    return _selectedStatus == HousekeepingTaskStatus.completed &&
        widget.task.status != 'Completed';
  }

  Future<void> _saveStatus() async {
    if (_selectedStatus.apiValue == widget.task.status) {
      AppErrorPresenter.showSnackBar(
        context,
        'Select a new cleaning status before saving.',
      );
      return;
    }

    if (_isCompleting &&
        widget.task.status == 'InProgress' &&
        _checklist.any((item) => !item)) {
      AppErrorPresenter.showSnackBar(
        context,
        'Complete every checklist item before finishing the task.',
      );
      return;
    }

    final roles =
        ref.read(authControllerProvider).userSession?.roles ?? const <String>[];
    final canInspect =
        roles.contains('HotelManager') || roles.contains('PropertyOwner');
    if (widget.task.status == 'InspectionRequired' &&
        _selectedStatus == HousekeepingTaskStatus.completed &&
        !canInspect) {
      AppErrorPresenter.showSnackBar(
        context,
        'A hotel manager must complete the room inspection.',
      );
      return;
    }

    setState(() => _saving = true);
    try {
      if (widget.task.status == 'InspectionRequired' &&
          _selectedStatus == HousekeepingTaskStatus.completed) {
        await ref.read(operationsApiProvider).completeHousekeepingInspection(
              hotelId: widget.hotelId,
              taskId: widget.task.id,
            );
      } else {
        await ref.read(operationsApiProvider).updateHousekeepingTaskStatus(
              hotelId: widget.hotelId,
              taskId: widget.task.id,
              status: _selectedStatus,
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
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _reportIssue() async {
    final reported = await showDialog<bool>(
      context: context,
      builder: (context) => _HousekeepingIssueDialog(
        hotelId: widget.hotelId,
        task: widget.task,
        initialDescription: _notesController.text.trim(),
      ),
    );
    if (reported == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final isReadOnly = task.status == 'Completed' || task.status == 'Cancelled';

    return SrsScreen(
      title: 'Housekeeping Task Detail Screen',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SrsPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SrsSectionTitle('Task Detail'),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 34,
                      backgroundColor: AppColors.surfaceSoft,
                      foregroundColor: AppColors.ink,
                      child: Icon(Icons.meeting_room_outlined, size: 34),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Room ${task.roomNumber}',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _IconDetailRow(
                            icon: Icons.warning_amber_rounded,
                            text:
                                'Status: ${housekeepingTaskStatusLabel(task.status)}',
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _IconDetailRow(
                            icon: Icons.calendar_month_outlined,
                            text:
                                'Due Date: ${AppFormatters.displayDateTime(housekeepingTargetCompletion(task))}',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SrsPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SrsFieldLabel('Cleaning Status'),
                DropdownButtonFormField<HousekeepingTaskStatus>(
                  initialValue: _selectedStatus,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.cleaning_services_outlined),
                  ),
                  items: [
                    for (final status in _availableStatuses)
                      DropdownMenuItem(
                        value: status,
                        child: Text(
                          housekeepingTaskStatusLabel(status.apiValue),
                        ),
                      ),
                  ],
                  onChanged: isReadOnly || _saving
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _selectedStatus = value);
                          }
                        },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SrsPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SrsSectionTitle('Checklist'),
                const SizedBox(height: AppSpacing.sm),
                for (var index = 0;
                    index < _checklistLabels.length;
                    index++) ...[
                  CheckboxListTile(
                    value: _checklist[index],
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    secondary: CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.surfaceSoft,
                      foregroundColor: AppColors.ink,
                      child: Icon(_checklistIcon(index), size: 20),
                    ),
                    title: Text(_checklistLabels[index]),
                    onChanged: isReadOnly || _saving
                        ? null
                        : (value) {
                            setState(() => _checklist[index] = value ?? false);
                          },
                  ),
                  if (index < _checklistLabels.length - 1)
                    const Divider(height: 1),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SrsPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SrsFieldLabel('Notes'),
                TextField(
                  controller: _notesController,
                  enabled: !isReadOnly && !_saving,
                  maxLength: 500,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Enter notes (optional)',
                    helperText:
                        'Notes prefill Report Issue and are not stored on '
                        'the housekeeping task.',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: isReadOnly || _saving ? null : _reportIssue,
            icon: const Icon(Icons.warning_amber_rounded),
            label: const Text('Report Issue'),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_saving)
            const LinearProgressIndicator()
          else
            FilledButton.icon(
              onPressed: isReadOnly ? null : _saveStatus,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save Status'),
            ),
        ],
      ),
    );
  }
}

class _IconDetailRow extends StatelessWidget {
  const _IconDetailRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: AppColors.surfaceSoft,
          foregroundColor: AppColors.ink,
          child: Icon(icon, size: 18),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class _HousekeepingIssueDialog extends ConsumerStatefulWidget {
  const _HousekeepingIssueDialog({
    required this.hotelId,
    required this.task,
    required this.initialDescription,
  });

  final String hotelId;
  final HousekeepingTask task;
  final String initialDescription;

  @override
  ConsumerState<_HousekeepingIssueDialog> createState() =>
      _HousekeepingIssueDialogState();
}

class _HousekeepingIssueDialogState
    extends ConsumerState<_HousekeepingIssueDialog> {
  late final TextEditingController _descriptionController;
  MaintenanceSeverity _severity = MaintenanceSeverity.medium;
  String _targetRoomStatus = 'Maintenance';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(
      text: widget.initialDescription,
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      AppErrorPresenter.showSnackBar(context, 'Enter issue details.');
      return;
    }

    setState(() => _submitting = true);
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
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Report issue for room ${widget.task.roomNumber}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _descriptionController,
              autofocus: true,
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
              onChanged: _submitting
                  ? null
                  : (value) {
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
              onChanged: _submitting
                  ? null
                  : (value) {
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
          onPressed:
              _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create Request'),
        ),
      ],
    );
  }
}

IconData _checklistIcon(int index) {
  return switch (index) {
    0 => Icons.bed_outlined,
    1 => Icons.dry_cleaning_outlined,
    2 => Icons.delete_outline,
    3 => Icons.cleaning_services_outlined,
    4 => Icons.cleaning_services_outlined,
    5 => Icons.chair_outlined,
    _ => Icons.assignment_turned_in_outlined,
  };
}
