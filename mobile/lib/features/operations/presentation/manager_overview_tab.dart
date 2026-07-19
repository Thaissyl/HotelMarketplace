import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../shared/widgets/app_error_presenter.dart';
import '../application/operations_providers.dart';
import '../domain/operations_models.dart';

class ManagerOverviewTab extends ConsumerWidget {
  const ManagerOverviewTab({
    super.key,
    required this.hotelId,
    required this.roles,
  });

  final String hotelId;
  final List<String> roles;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hotels = ref.watch(workingHotelsProvider);
    final housekeeping = ref.watch(
      housekeepingTasksProvider(HousekeepingTasksRequest(hotelId: hotelId)),
    );
    final maintenance = ref.watch(
      maintenanceRequestsProvider(MaintenanceRequestsRequest(hotelId: hotelId)),
    );

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(workingHotelsProvider);
        ref.invalidate(
          housekeepingTasksProvider(HousekeepingTasksRequest(hotelId: hotelId)),
        );
        ref.invalidate(
          maintenanceRequestsProvider(
            MaintenanceRequestsRequest(hotelId: hotelId),
          ),
        );
      },
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          hotels.when(
            data: (items) {
              final hotel = items.firstWhere(
                (item) => item.id == hotelId,
                orElse: () => WorkingHotel.fallback(hotelId),
              );

              return _HotelHeader(hotel: hotel, roles: roles);
            },
            error: (error, stackTrace) => _HotelHeader(
              hotel: WorkingHotel.fallback(hotelId),
              roles: roles,
            ),
            loading: () => const LinearProgressIndicator(),
          ),
          const SizedBox(height: AppSpacing.md),
          const _SectionTitle(
            title: 'Today at a glance',
            subtitle: 'Operational pressure for the selected hotel.',
          ),
          const SizedBox(height: AppSpacing.sm),
          housekeeping.when(
            data: (housekeepingItems) {
              return maintenance.when(
                data: (maintenanceItems) => _StatusBoard(
                  housekeepingTasks: housekeepingItems,
                  maintenanceRequests: maintenanceItems,
                ),
                error: (error, stackTrace) => const _StatusBoardError(),
                loading: () => const _MetricSkeletonGrid(),
              );
            },
            error: (error, stackTrace) => const _StatusBoardError(),
            loading: () => const _MetricSkeletonGrid(),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _SectionTitle(
            title: 'Cleaning assignments',
            subtitle: 'Assign open housekeeping tasks to room attendants.',
          ),
          const SizedBox(height: AppSpacing.sm),
          housekeeping.when(
            data: (items) => _HousekeepingAssignmentPreview(
              hotelId: hotelId,
              items: items,
            ),
            error: (error, stackTrace) => const _EmptyPanel(
              icon: Icons.error_outline_rounded,
              title: 'Unable to load housekeeping',
              message: 'Pull down to refresh or check the backend connection.',
            ),
            loading: () => const LinearProgressIndicator(),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _SectionTitle(
            title: 'Open maintenance',
            subtitle: 'Issues that can block room sales or guest service.',
          ),
          const SizedBox(height: AppSpacing.sm),
          maintenance.when(
            data: (items) =>
                _MaintenancePreview(hotelId: hotelId, items: items),
            error: (error, stackTrace) => const _EmptyPanel(
              icon: Icons.error_outline_rounded,
              title: 'Unable to load maintenance',
              message: 'Pull down to refresh or check the backend connection.',
            ),
            loading: () => const LinearProgressIndicator(),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _ManagerWorkflowCard(),
        ],
      ),
    );
  }
}

class _HotelHeader extends StatelessWidget {
  const _HotelHeader({
    required this.hotel,
    required this.roles,
  });

  final WorkingHotel hotel;
  final List<String> roles;

  @override
  Widget build(BuildContext context) {
    final hasRealHotelName = hotel.name.trim().isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hasRealHotelName ? hotel.displayName : 'Assigned hotel',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              hasRealHotelName
                  ? hotel.subtitle
                  : 'Hotel information is not available from the API yet.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (!hasRealHotelName) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                hotel.shortCode,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                _Pill(
                  label: 'Role: ${_roleLabel(roles)}',
                  color: AppColors.brand,
                ),
                if (hotel.approvalStatus.isNotEmpty)
                  _Pill(
                    label: 'Approval: ${hotel.approvalStatus}',
                    color: AppColors.success,
                  ),
                if (hotel.publicationStatus.isNotEmpty)
                  _Pill(
                    label: 'Listing: ${hotel.publicationStatus}',
                    color: AppColors.success,
                  ),
                if (hotel.contactPhone.isNotEmpty)
                  _Pill(
                    label: hotel.contactPhone,
                    color: AppColors.mutedInk,
                  ),
                if (hotel.contactEmail.isNotEmpty)
                  _Pill(
                    label: hotel.contactEmail,
                    color: AppColors.mutedInk,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xxs),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _StatusBoard extends StatelessWidget {
  const _StatusBoard({
    required this.housekeepingTasks,
    required this.maintenanceRequests,
  });

  final List<HousekeepingTask> housekeepingTasks;
  final List<MaintenanceRequestItem> maintenanceRequests;

  @override
  Widget build(BuildContext context) {
    final waitingCleaning = housekeepingTasks
        .where((task) => task.status == HousekeepingTaskStatus.open.apiValue)
        .length;
    final inProgressCleaning = housekeepingTasks
        .where(
          (task) => task.status == HousekeepingTaskStatus.inProgress.apiValue,
        )
        .length;
    final openMaintenance = maintenanceRequests
        .where((item) => item.status == MaintenanceStatus.open.apiValue)
        .length;
    final urgentMaintenance = maintenanceRequests
        .where((item) => item.severity == MaintenanceSeverity.critical.apiValue)
        .length;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: 1.35,
      children: [
        _StatusTile(
          title: 'Waiting clean',
          value: waitingCleaning.toString(),
          helper: 'Rooms that cannot be sold yet',
          icon: Icons.cleaning_services_rounded,
          color: AppColors.warning,
        ),
        _StatusTile(
          title: 'Cleaning now',
          value: inProgressCleaning.toString(),
          helper: 'Tasks currently handled by staff',
          icon: Icons.local_laundry_service_rounded,
          color: AppColors.brand,
        ),
        _StatusTile(
          title: 'Open repairs',
          value: openMaintenance.toString(),
          helper: 'Maintenance requests not resolved',
          icon: Icons.handyman_rounded,
          color: AppColors.danger,
        ),
        _StatusTile(
          title: 'Critical',
          value: urgentMaintenance.toString(),
          helper: 'High-priority room blockers',
          icon: Icons.priority_high_rounded,
          color: AppColors.danger,
        ),
      ],
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({
    required this.title,
    required this.value,
    required this.helper,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final String helper;
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
            Row(
              children: [
                Icon(icon, color: color),
                const Spacer(),
                Text(value, style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xxs),
            Expanded(
              child: Text(
                helper,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HousekeepingAssignmentPreview extends StatelessWidget {
  const _HousekeepingAssignmentPreview({
    required this.hotelId,
    required this.items,
  });

  final String hotelId;
  final List<HousekeepingTask> items;

  @override
  Widget build(BuildContext context) {
    final openItems = items
        .where((item) => item.status == HousekeepingTaskStatus.open.apiValue)
        .take(4)
        .toList(growable: false);

    if (openItems.isEmpty) {
      return const _EmptyPanel(
        icon: Icons.cleaning_services_rounded,
        title: 'No open cleaning tasks',
        message: 'Checkout-generated cleaning work will appear here.',
      );
    }

    return Column(
      children: [
        for (final item in openItems)
          _HousekeepingAssignmentCard(hotelId: hotelId, item: item),
      ],
    );
  }
}

class _HousekeepingAssignmentCard extends ConsumerWidget {
  const _HousekeepingAssignmentCard({
    required this.hotelId,
    required this.item,
  });

  final String hotelId;
  final HousekeepingTask item;

  Future<void> _assign(BuildContext context, WidgetRef ref) async {
    final staff = await ref.read(hotelStaffProvider(hotelId).future);
    if (!context.mounted) {
      return;
    }

    final assignee = await _chooseStaff(
      context,
      staff.where((member) => member.role == 'HousekeepingStaff').toList(),
      'Assign housekeeping',
    );
    if (assignee == null || !context.mounted) {
      return;
    }

    try {
      await ref.read(operationsApiProvider).assignHousekeepingTask(
            hotelId: hotelId,
            taskId: item.id,
            assignedToUserAccountId: assignee.userAccountId,
          );
      ref.invalidate(
        housekeepingTasksProvider(HousekeepingTasksRequest(hotelId: hotelId)),
      );
      if (context.mounted) {
        AppErrorPresenter.showSnackBar(
          context,
          'Assigned to ${assignee.fullName}.',
        );
      }
    } catch (error) {
      if (context.mounted) {
        await AppErrorPresenter.showBottomSheet(context, error);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            const Icon(Icons.cleaning_services_rounded, color: AppColors.brand),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Room ${item.roomNumber}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text('${item.taskType} - ${item.roomStatus}'),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () => _assign(context, ref),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Assign'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaintenancePreview extends StatelessWidget {
  const _MaintenancePreview({
    required this.hotelId,
    required this.items,
  });

  final String hotelId;
  final List<MaintenanceRequestItem> items;

  @override
  Widget build(BuildContext context) {
    final openItems = items
        .where(
          (item) =>
              item.status != MaintenanceStatus.resolved.apiValue &&
              item.status != MaintenanceStatus.released.apiValue,
        )
        .take(3)
        .toList(growable: false);

    if (openItems.isEmpty) {
      return const _EmptyPanel(
        icon: Icons.verified_rounded,
        title: 'No open maintenance',
        message: 'All rooms are clear from active maintenance requests.',
      );
    }

    return Column(
      children: [
        for (final item in openItems)
          _MaintenanceIssueCard(hotelId: hotelId, item: item),
      ],
    );
  }
}

class _MaintenanceIssueCard extends ConsumerWidget {
  const _MaintenanceIssueCard({
    required this.hotelId,
    required this.item,
  });

  final String hotelId;
  final MaintenanceRequestItem item;

  Future<void> _assign(BuildContext context, WidgetRef ref) async {
    final staff = await ref.read(hotelStaffProvider(hotelId).future);
    if (!context.mounted) {
      return;
    }

    final assignee = await _chooseStaff(
      context,
      staff.where((member) => member.role == 'MaintenanceStaff').toList(),
      'Assign maintenance',
    );
    if (assignee == null || !context.mounted) {
      return;
    }

    try {
      await ref.read(operationsApiProvider).assignMaintenanceRequest(
            hotelId: hotelId,
            requestId: item.id,
            assignedToUserAccountId: assignee.userAccountId,
          );
      ref.invalidate(
        maintenanceRequestsProvider(
          MaintenanceRequestsRequest(hotelId: hotelId),
        ),
      );
      if (context.mounted) {
        AppErrorPresenter.showSnackBar(
          context,
          'Assigned to ${assignee.fullName}.',
        );
      }
    } catch (error) {
      if (context.mounted) {
        await AppErrorPresenter.showBottomSheet(context, error);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: const Icon(
                Icons.handyman_rounded,
                color: AppColors.danger,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Room ${item.roomNumber}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    item.description.isEmpty
                        ? 'No description provided'
                        : item.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      _Pill(label: item.severity, color: AppColors.danger),
                      _Pill(label: item.status, color: AppColors.brand),
                      _Pill(
                        label: item.displayCreatedAt,
                        color: AppColors.mutedInk,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _assign(context, ref),
                      icon: const Icon(Icons.engineering_rounded),
                      label: const Text('Assign technician'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<HotelStaffMember?> _chooseStaff(
  BuildContext context,
  List<HotelStaffMember> staff,
  String title,
) {
  if (staff.isEmpty) {
    AppErrorPresenter.showSnackBar(
      context,
      'No matching staff account is available for this hotel.',
    );
    return Future.value();
  }

  return showModalBottomSheet<HotelStaffMember>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.lg,
          ),
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            for (final member in staff)
              ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.person_rounded),
                ),
                title: Text(member.fullName),
                subtitle: Text('${member.email} - ${member.phoneNumber ?? ''}'),
                onTap: () => Navigator.of(context).pop(member),
              ),
          ],
        ),
      );
    },
  );
}

class _MetricSkeletonGrid extends StatelessWidget {
  const _MetricSkeletonGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: 1.35,
      children: const [
        _MetricSkeleton(),
        _MetricSkeleton(),
        _MetricSkeleton(),
        _MetricSkeleton(),
      ],
    );
  }
}

class _MetricSkeleton extends StatelessWidget {
  const _MetricSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: LinearProgressIndicator(),
      ),
    );
  }
}

class _StatusBoardError extends StatelessWidget {
  const _StatusBoardError();

  @override
  Widget build(BuildContext context) {
    return const _EmptyPanel(
      icon: Icons.error_outline_rounded,
      title: 'Unable to load operations',
      message: 'Pull down to refresh or check the backend connection.',
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Icon(icon, color: AppColors.mutedInk),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  Text(message, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManagerWorkflowCard extends StatelessWidget {
  const _ManagerWorkflowCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Manager workflow',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            const _WorkflowStep(
              icon: Icons.room_service_rounded,
              title: 'Front Desk tab',
              body:
                  'Assign available physical rooms, complete check-in, process checkout, and create walk-in bookings.',
            ),
            const _WorkflowStep(
              icon: Icons.cleaning_services_rounded,
              title: 'Rooms tab',
              body:
                  'Track dirty rooms, see which tasks are claimed, and confirm rooms return to Available after cleaning.',
            ),
            const _WorkflowStep(
              icon: Icons.handyman_rounded,
              title: 'Maintenance tab',
              body:
                  'Create repair requests, follow active issues, resolve repairs, and release rooms back to inventory.',
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkflowStep extends StatelessWidget {
  const _WorkflowStep({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Icon(icon, color: AppColors.brand),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                Text(body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
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

String _roleLabel(List<String> roles) {
  if (roles.contains('PropertyOwner')) {
    return 'Owner';
  }
  if (roles.contains('HotelManager')) {
    return 'Hotel manager';
  }
  if (roles.contains('Receptionist')) {
    return 'Receptionist';
  }
  if (roles.contains('HousekeepingStaff')) {
    return 'Housekeeping';
  }
  if (roles.contains('MaintenanceStaff')) {
    return 'Maintenance';
  }

  return 'Operations';
}
