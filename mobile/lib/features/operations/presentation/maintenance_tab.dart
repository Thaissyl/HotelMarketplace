import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../shared/widgets/app_error_presenter.dart';
import '../application/operations_providers.dart';
import '../domain/operations_models.dart';

class MaintenanceTab extends ConsumerStatefulWidget {
  const MaintenanceTab({super.key, required this.hotelId});

  final String hotelId;

  @override
  ConsumerState<MaintenanceTab> createState() => _MaintenanceTabState();
}

class _MaintenanceTabState extends ConsumerState<MaintenanceTab> {
  final _roomId = TextEditingController();
  final _description = TextEditingController();
  MaintenanceSeverity _severity = MaintenanceSeverity.medium;
  String _targetStatus = 'Maintenance';
  bool _reporting = false;

  @override
  void dispose() {
    _roomId.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _reportIssue() async {
    if (_roomId.text.trim().isEmpty || _description.text.trim().isEmpty) {
      AppErrorPresenter.showSnackBar(
        context,
        'Room id and issue description are required.',
      );
      return;
    }

    setState(() => _reporting = true);
    try {
      await ref.read(operationsApiProvider).reportMaintenanceIssue(
            hotelId: widget.hotelId,
            physicalRoomId: _roomId.text.trim(),
            description: _description.text,
            severity: _severity,
            targetRoomStatus: _targetStatus,
          );
      _roomId.clear();
      _description.clear();
      ref.invalidate(
        maintenanceRequestsProvider(
          MaintenanceRequestsRequest(hotelId: widget.hotelId),
        ),
      );
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
    final request = MaintenanceRequestsRequest(hotelId: widget.hotelId);
    final requests = ref.watch(maintenanceRequestsProvider(request));

    return RefreshIndicator(
      onRefresh: () async =>
          ref.invalidate(maintenanceRequestsProvider(request)),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _ReportIssueCard(
            roomId: _roomId,
            description: _description,
            severity: _severity,
            targetStatus: _targetStatus,
            reporting: _reporting,
            onSeverityChanged: (value) => setState(() => _severity = value),
            onTargetChanged: (value) => setState(() => _targetStatus = value),
            onSubmit: _reportIssue,
          ),
          const SizedBox(height: AppSpacing.md),
          requests.when(
            data: (items) {
              if (items.isEmpty) {
                return const _EmptyMaintenance();
              }

              return Column(
                children: [
                  for (final item in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _MaintenanceCard(
                        hotelId: widget.hotelId,
                        item: item,
                        onUpdated: () => ref
                            .invalidate(maintenanceRequestsProvider(request)),
                      ),
                    ),
                ],
              );
            },
            error: (error, stackTrace) => const Text(
              'Unable to load maintenance requests.',
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
    );
  }
}

class _ReportIssueCard extends StatelessWidget {
  const _ReportIssueCard({
    required this.roomId,
    required this.description,
    required this.severity,
    required this.targetStatus,
    required this.reporting,
    required this.onSeverityChanged,
    required this.onTargetChanged,
    required this.onSubmit,
  });

  final TextEditingController roomId;
  final TextEditingController description;
  final MaintenanceSeverity severity;
  final String targetStatus;
  final bool reporting;
  final ValueChanged<MaintenanceSeverity> onSeverityChanged;
  final ValueChanged<String> onTargetChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Report issue',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: roomId,
              decoration: const InputDecoration(labelText: 'Physical room ID'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: description,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Issue description'),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<MaintenanceSeverity>(
              initialValue: severity,
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
                  onSeverityChanged(value);
                }
              },
            ),
            const SizedBox(height: AppSpacing.md),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'Maintenance', label: Text('Maintenance')),
                ButtonSegment(value: 'OutOfService', label: Text('Out')),
              ],
              selected: {targetStatus},
              onSelectionChanged: (value) => onTargetChanged(value.first),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: reporting ? null : onSubmit,
              icon: reporting
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

  Future<void> _setStatus(MaintenanceStatus status) async {
    setState(() => _loading = true);
    try {
      await ref.read(operationsApiProvider).updateMaintenanceRequestStatus(
            hotelId: widget.hotelId,
            requestId: widget.item.id,
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
    final item = widget.item;
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
                  child: Text(
                    'Room ${item.roomNumber}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(item.severity),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(item.description),
            const SizedBox(height: AppSpacing.xs),
            Text('Status: ${item.status} · Room: ${item.roomStatus}'),
            const SizedBox(height: AppSpacing.lg),
            if (_loading)
              const LinearProgressIndicator()
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: item.status == 'Open'
                          ? () => _setStatus(MaintenanceStatus.inProgress)
                          : null,
                      child: const Text('Start'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: item.status == 'InProgress'
                          ? () => _setStatus(MaintenanceStatus.resolved)
                          : null,
                      child: const Text('Resolve'),
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
