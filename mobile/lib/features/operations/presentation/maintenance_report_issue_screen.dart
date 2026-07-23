import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../shared/widgets/app_error_presenter.dart';
import '../../../shared/widgets/srs_screen.dart';
import '../application/operations_providers.dart';
import '../domain/operations_models.dart';

class MaintenanceReportIssueScreen extends ConsumerStatefulWidget {
  const MaintenanceReportIssueScreen({super.key, required this.hotelId});

  final String hotelId;

  @override
  ConsumerState<MaintenanceReportIssueScreen> createState() =>
      _MaintenanceReportIssueScreenState();
}

class _MaintenanceReportIssueScreenState
    extends ConsumerState<MaintenanceReportIssueScreen> {
  final _descriptionController = TextEditingController();
  String? _roomId;
  MaintenanceSeverity _severity = MaintenanceSeverity.medium;
  String _targetRoomStatus = 'Maintenance';
  bool _submitting = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final description = _descriptionController.text.trim();
    if (_roomId == null) {
      AppErrorPresenter.showSnackBar(context, 'Select the affected room.');
      return;
    }
    if (description.length < 5) {
      AppErrorPresenter.showSnackBar(
        context,
        'Describe the issue using at least 5 characters.',
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(operationsApiProvider).reportMaintenanceIssue(
            hotelId: widget.hotelId,
            physicalRoomId: _roomId!,
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
    final rooms = ref.watch(maintenanceRoomsProvider(widget.hotelId));

    return SrsScreen(
      title: 'Create Maintenance Request',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SrsPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SrsSectionTitle('Issue Information'),
                const SizedBox(height: AppSpacing.md),
                rooms.when(
                  data: (items) {
                    final eligibleRooms = items
                        .where(
                          (room) => !const {
                            'Occupied',
                            'Maintenance',
                            'OutOfService',
                            'Inactive',
                          }.contains(room.status),
                        )
                        .toList(growable: false)
                      ..sort(
                        (left, right) =>
                            left.roomNumber.compareTo(right.roomNumber),
                      );
                    if (eligibleRooms.isEmpty) {
                      return const Text(
                        'No rooms are currently eligible for a new '
                        'maintenance request.',
                      );
                    }
                    return DropdownButtonFormField<String>(
                      initialValue: _roomId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Room',
                        prefixIcon: Icon(Icons.meeting_room_outlined),
                      ),
                      items: [
                        for (final room in eligibleRooms)
                          DropdownMenuItem(
                            value: room.id,
                            child: Text(
                              'Room ${room.roomNumber} - ${room.status}',
                            ),
                          ),
                      ],
                      onChanged: _submitting
                          ? null
                          : (value) => setState(() => _roomId = value),
                    );
                  },
                  error: (error, stackTrace) => const Text(
                    'Unable to load rooms. Return and try again.',
                  ),
                  loading: () => const LinearProgressIndicator(),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _descriptionController,
                  enabled: !_submitting,
                  maxLength: 1000,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Describe the fault and where it was found.',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<MaintenanceSeverity>(
                  initialValue: _severity,
                  decoration: const InputDecoration(
                    labelText: 'Severity',
                    prefixIcon: Icon(Icons.warning_amber_rounded),
                  ),
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
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  initialValue: _targetRoomStatus,
                  decoration: const InputDecoration(
                    labelText: 'Room Impact',
                    prefixIcon: Icon(Icons.block_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Maintenance',
                      child: Text('Maintenance'),
                    ),
                    DropdownMenuItem(
                      value: 'OutOfService',
                      child: Text('Out of Service'),
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
          const SizedBox(height: AppSpacing.lg),
          if (_submitting)
            const LinearProgressIndicator()
          else
            FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.add_alert_outlined),
              label: const Text('Create Request'),
            ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'The room is removed from normal inventory immediately after '
            'the request is accepted.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.mutedInk),
          ),
        ],
      ),
    );
  }
}
