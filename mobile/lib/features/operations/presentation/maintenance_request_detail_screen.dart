import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../shared/widgets/app_error_presenter.dart';
import '../../../shared/widgets/srs_screen.dart';
import '../../auth/application/auth_controller.dart';
import '../application/operations_providers.dart';
import '../domain/operations_models.dart';
import 'maintenance_request_ui.dart';

class MaintenanceRequestDetailScreen extends ConsumerStatefulWidget {
  const MaintenanceRequestDetailScreen({
    super.key,
    required this.hotelId,
    required this.request,
  });

  final String hotelId;
  final MaintenanceRequestItem request;

  @override
  ConsumerState<MaintenanceRequestDetailScreen> createState() =>
      _MaintenanceRequestDetailScreenState();
}

class _MaintenanceRequestDetailScreenState
    extends ConsumerState<MaintenanceRequestDetailScreen> {
  late MaintenanceStatus _selectedStatus;
  late String? _assigneeId;
  late final TextEditingController _resolutionController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedStatus = MaintenanceStatus.values.firstWhere(
      (status) => status.apiValue == widget.request.status,
      orElse: () => MaintenanceStatus.open,
    );
    _assigneeId = widget.request.assignedToUserAccountId;
    _resolutionController = TextEditingController(
      text: widget.request.resolutionNote ?? '',
    );
  }

  @override
  void dispose() {
    _resolutionController.dispose();
    super.dispose();
  }

  bool get _canRelease {
    final roles =
        ref.read(authControllerProvider).userSession?.roles ?? const <String>[];
    return roles.contains('MaintenanceStaff') ||
        roles.contains('HotelManager') ||
        roles.contains('PropertyOwner');
  }

  bool get _roomCanBeReleased {
    return widget.request.roomStatus == 'Available' ||
        widget.request.roomStatus == 'InspectionRequired';
  }

  List<MaintenanceStatus> get _availableStatuses {
    return switch (widget.request.status) {
      'Open' => const [
          MaintenanceStatus.open,
          MaintenanceStatus.inProgress,
        ],
      'InProgress' => const [
          MaintenanceStatus.inProgress,
          MaintenanceStatus.resolved,
        ],
      'Resolved' => [
          MaintenanceStatus.resolved,
          if (_canRelease && _roomCanBeReleased) MaintenanceStatus.released,
        ],
      'Released' => const [MaintenanceStatus.released],
      _ => [_selectedStatus],
    };
  }

  Future<void> _save() async {
    final statusChanged = _selectedStatus.apiValue != widget.request.status;
    final assigneeChanged = _assigneeId != null &&
        _assigneeId != widget.request.assignedToUserAccountId;
    if (!statusChanged && !assigneeChanged) {
      AppErrorPresenter.showSnackBar(
        context,
        'Select a new status or assignee before saving.',
      );
      return;
    }

    final resolutionNote = _resolutionController.text.trim();
    if (_selectedStatus == MaintenanceStatus.resolved &&
        resolutionNote.isEmpty) {
      AppErrorPresenter.showSnackBar(
        context,
        'Enter a diagnosis or resolution note.',
      );
      return;
    }

    setState(() => _saving = true);
    try {
      if (assigneeChanged) {
        await ref.read(operationsApiProvider).assignMaintenanceRequest(
              hotelId: widget.hotelId,
              requestId: widget.request.id,
              assignedToUserAccountId: _assigneeId!,
            );
      }
      if (statusChanged) {
        await ref.read(operationsApiProvider).updateMaintenanceRequestStatus(
              hotelId: widget.hotelId,
              requestId: widget.request.id,
              status: _selectedStatus,
              resolutionNote: _selectedStatus == MaintenanceStatus.resolved
                  ? resolutionNote
                  : null,
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

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final staff = ref.watch(hotelStaffProvider(widget.hotelId));
    final readOnly =
        request.status == 'Released' || request.status == 'Cancelled';
    final issueType = maintenanceIssueType(request.description);
    final issueTitle = maintenanceIssueTitle(request.description);

    return SrsScreen(
      title: 'Maintenance Request Detail Screen',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SrsPanel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: AppColors.surfaceSoft,
                        foregroundColor: AppColors.ink,
                        child: Icon(Icons.assignment_outlined),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Issue Information',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                _InformationRow(
                  icon: Icons.meeting_room_outlined,
                  label: 'Room',
                  value: 'Room ${request.roomNumber}',
                ),
                const Divider(height: 1),
                _InformationRow(
                  icon: Icons.build_outlined,
                  label: 'Issue Type',
                  value: '$issueType - $issueTitle',
                ),
                const Divider(height: 1),
                _InformationRow(
                  icon: Icons.warning_amber_rounded,
                  label: 'Severity',
                  value: request.severity,
                ),
                const Divider(height: 1),
                _DescriptionRow(description: request.description),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const SrsFieldLabel('Current Status'),
          DropdownButtonFormField<MaintenanceStatus>(
            initialValue: _selectedStatus,
            isExpanded: true,
            items: [
              for (final status in _availableStatuses)
                DropdownMenuItem(
                  value: status,
                  child: Text(maintenanceStatusLabel(status.apiValue)),
                ),
            ],
            onChanged: readOnly || _saving
                ? null
                : (value) {
                    if (value != null) {
                      setState(() => _selectedStatus = value);
                    }
                  },
          ),
          const SizedBox(height: AppSpacing.lg),
          const SrsFieldLabel('Assignee'),
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
              final visibleValue =
                  knownIds.contains(_assigneeId) ? _assigneeId : null;
              return DropdownButtonFormField<String?>(
                initialValue: visibleValue,
                isExpanded: true,
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Select Assignee'),
                  ),
                  for (final member in maintainers)
                    DropdownMenuItem(
                      value: member.userAccountId,
                      child: Text(member.fullName),
                    ),
                ],
                onChanged: !_canRelease || request.status != 'Open' || _saving
                    ? null
                    : (value) => setState(() => _assigneeId = value),
              );
            },
            error: (error, stackTrace) => InputDecorator(
              decoration: const InputDecoration(),
              child: Text(
                request.assignedToUserAccountId == null
                    ? 'Unassigned'
                    : 'Assigned technician',
              ),
            ),
            loading: () => const LinearProgressIndicator(),
          ),
          const SizedBox(height: AppSpacing.lg),
          const SrsFieldLabel('Diagnosis/Resolution Note'),
          TextField(
            controller: _resolutionController,
            enabled: !readOnly && !_saving,
            maxLength: 1000,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Enter diagnosis or resolution note...',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const SrsFieldLabel('Release Room Option'),
          DropdownButtonFormField<String>(
            initialValue: 'Automatic',
            isExpanded: true,
            items: [
              DropdownMenuItem(
                value: 'Automatic',
                child: Text(_releaseRoomLabel(request)),
              ),
            ],
            onChanged: null,
          ),
          if (request.status == 'Resolved' &&
              _canRelease &&
              !_roomCanBeReleased) ...[
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'The room must complete housekeeping before this maintenance '
              'request can be released.',
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          if (_saving)
            const LinearProgressIndicator()
          else
            FilledButton(
              onPressed: readOnly ? null : _save,
              child: const Text('Save Update'),
            ),
        ],
      ),
    );
  }
}

class _InformationRow extends StatelessWidget {
  const _InformationRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.surfaceSoft,
            foregroundColor: AppColors.ink,
            child: Icon(icon, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(label)),
          const SizedBox(width: AppSpacing.md),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}

class _DescriptionRow extends StatelessWidget {
  const _DescriptionRow({required this.description});

  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.surfaceSoft,
            foregroundColor: AppColors.ink,
            child: Icon(Icons.description_outlined, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Description'),
                const SizedBox(height: AppSpacing.xs),
                Text(description),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _releaseRoomLabel(MaintenanceRequestItem request) {
  if (request.status == 'Released') {
    return 'Available';
  }
  if (request.roomStatus == 'InspectionRequired') {
    return 'Inspection Required';
  }
  if (request.roomStatus == 'Dirty') {
    return 'Dirty';
  }
  return '${request.roomStatus} (managed by hotel policy)';
}
