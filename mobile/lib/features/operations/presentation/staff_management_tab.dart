import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../shared/widgets/app_error_presenter.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../application/operations_providers.dart';
import '../domain/operations_models.dart';
import 'front_desk_components.dart';
import 'staff_components.dart';
import 'staff_entry_screen.dart';
import 'staff_role_assignment_screen.dart';

class StaffManagementTab extends ConsumerStatefulWidget {
  const StaffManagementTab({super.key, required this.hotelId});

  final String hotelId;

  @override
  ConsumerState<StaffManagementTab> createState() => _StaffManagementTabState();
}

class _StaffManagementTabState extends ConsumerState<StaffManagementTab> {
  String? _updatingAssignmentId;

  Future<void> _refresh() async {
    ref.invalidate(hotelStaffProvider(widget.hotelId));
  }

  Future<void> _openStaffEntry(
    List<String> availableRoles,
  ) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => StaffEntryScreen(
          hotelId: widget.hotelId,
          availableRoles: availableRoles,
        ),
      ),
    );
    if (changed == true && mounted) {
      await _refresh();
    }
  }

  Future<void> _openRoleAssignment({
    required HotelStaffMember member,
    required List<HotelStaffMember> staff,
    required List<String> availableRoles,
  }) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => StaffRoleAssignmentScreen(
          currentHotelId: widget.hotelId,
          staffMembers: staff,
          initialStaffMember: member,
          availableRoles: availableRoles,
        ),
      ),
    );
    if (changed == true && mounted) {
      await _refresh();
    }
  }

  Future<void> _setAssignmentActive(
    HotelStaffMember member,
    bool active,
  ) async {
    setState(() => _updatingAssignmentId = member.assignmentId);
    try {
      await ref.read(operationsApiProvider).updateStaffAssignment(
            hotelId: widget.hotelId,
            assignmentId: member.assignmentId,
            request: UpdateStaffAssignmentRequest(isActive: active),
          );
      await _refresh();
      if (mounted) {
        AppErrorPresenter.showSnackBar(
          context,
          active ? 'Hotel access activated.' : 'Hotel access deactivated.',
        );
      }
    } catch (error) {
      if (mounted) {
        await AppErrorPresenter.showBottomSheet(
          context,
          error,
          title: 'Staff status not updated',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _updatingAssignmentId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider).userSession;
    final isPropertyOwner =
        session?.roles.contains(UserRoleCode.propertyOwner.apiValue) ?? false;
    final roles = availableHotelStaffRoles(
      isPropertyOwner: isPropertyOwner,
    );
    final staffState = ref.watch(hotelStaffProvider(widget.hotelId));

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openStaffEntry(roles),
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('Invite/Create Staff'),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Staff List', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.md),
          staffState.when(
            loading: () => const FrontDeskLoadingState(),
            error: (error, stackTrace) => FrontDeskErrorState(
              error: error,
              title: 'Unable to load staff accounts',
              onRetry: _refresh,
            ),
            data: (staff) {
              if (staff.isEmpty) {
                return const FrontDeskEmptyState(
                  title: 'No staff assigned',
                  message: 'Invite or attach a staff account to this hotel.',
                );
              }
              return _StaffTable(
                staff: staff,
                currentUserId: session?.userId,
                manageableRoles: roles,
                updatingAssignmentId: _updatingAssignmentId,
                onOpenMember: (member) => _openRoleAssignment(
                  member: member,
                  staff: staff
                      .where((item) => roles.contains(item.role))
                      .toList(growable: false),
                  availableRoles: roles,
                ),
                onSetActive: _setAssignmentActive,
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _StaffTable extends StatelessWidget {
  const _StaffTable({
    required this.staff,
    required this.currentUserId,
    required this.manageableRoles,
    required this.updatingAssignmentId,
    required this.onOpenMember,
    required this.onSetActive,
  });

  final List<HotelStaffMember> staff;
  final String? currentUserId;
  final List<String> manageableRoles;
  final String? updatingAssignmentId;
  final ValueChanged<HotelStaffMember> onOpenMember;
  final Future<void> Function(HotelStaffMember member, bool active) onSetActive;

  @override
  Widget build(BuildContext context) {
    return FrontDeskPanel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          const _StaffTableHeader(),
          for (var index = 0; index < staff.length; index++) ...[
            const Divider(height: 1),
            _StaffTableRow(
              member: staff[index],
              isCurrentUser: staff[index].userAccountId == currentUserId,
              canManageRole: manageableRoles.contains(staff[index].role),
              busy: updatingAssignmentId == staff[index].assignmentId,
              onOpen: () => onOpenMember(staff[index]),
              onSetActive: (active) => onSetActive(staff[index], active),
            ),
          ],
        ],
      ),
    );
  }
}

class _StaffTableHeader extends StatelessWidget {
  const _StaffTableHeader();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(flex: 5, child: Text('Staff Name', style: style)),
          const SizedBox(width: AppSpacing.xs),
          Expanded(flex: 5, child: Text('Email/Phone', style: style)),
          const SizedBox(width: AppSpacing.xs),
          SizedBox(width: 82, child: Text('Status', style: style)),
          const SizedBox(width: 76),
        ],
      ),
    );
  }
}

class _StaffTableRow extends StatelessWidget {
  const _StaffTableRow({
    required this.member,
    required this.isCurrentUser,
    required this.canManageRole,
    required this.busy,
    required this.onOpen,
    required this.onSetActive,
  });

  final HotelStaffMember member;
  final bool isCurrentUser;
  final bool canManageRole;
  final bool busy;
  final VoidCallback onOpen;
  final ValueChanged<bool> onSetActive;

  @override
  Widget build(BuildContext context) {
    final accountActive = member.status == 'Active';
    final assignmentActive = member.isAssignmentActive && accountActive;
    final canManage = !isCurrentUser && canManageRole && accountActive;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: InkWell(
              onTap: canManage ? onOpen : null,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    child: Text(_initials(member.fullName, member.email)),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      member.fullName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            flex: 5,
            child: InkWell(
              onTap: canManage ? onOpen : null,
              child: Text(
                member.email,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          SizedBox(
            width: 82,
            child: busy
                ? const Center(
                    child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _StatusDropdown(
                    active: assignmentActive,
                    enabled: canManage,
                    onChanged: onSetActive,
                  ),
          ),
          const SizedBox(width: AppSpacing.xs),
          SizedBox(
            width: 68,
            child: OutlinedButton(
              onPressed: busy || !canManage
                  ? null
                  : () => onSetActive(!assignmentActive),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: const Size(0, 44),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(assignmentActive ? 'Deactivate' : 'Activate'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusDropdown extends StatelessWidget {
  const _StatusDropdown({
    required this.active,
    required this.enabled,
    required this.onChanged,
  });

  final bool active;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<bool>(
          value: active,
          isExpanded: true,
          style: Theme.of(context).textTheme.bodySmall,
          items: const [
            DropdownMenuItem(value: true, child: Text('Active')),
            DropdownMenuItem(value: false, child: Text('Inactive')),
          ],
          onChanged: !enabled
              ? null
              : (value) {
                  if (value != null && value != active) {
                    onChanged(value);
                  }
                },
        ),
      ),
    );
  }
}

String _initials(String fullName, String email) {
  final parts = fullName
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.length >= 2) {
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
  if (parts.length == 1) {
    return parts.first[0].toUpperCase();
  }
  return email.isEmpty ? '?' : email[0].toUpperCase();
}
