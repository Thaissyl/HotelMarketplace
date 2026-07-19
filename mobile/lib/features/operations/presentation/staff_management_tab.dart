import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../shared/widgets/app_error_presenter.dart';
import '../../../shared/widgets/app_text_form_field.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../application/operations_providers.dart';
import '../domain/operations_models.dart';

class StaffManagementTab extends ConsumerStatefulWidget {
  const StaffManagementTab({super.key, required this.hotelId});

  final String hotelId;

  @override
  ConsumerState<StaffManagementTab> createState() => _StaffManagementTabState();
}

enum _StaffEntryMode { create, attach }

class _StaffManagementTabState extends ConsumerState<StaffManagementTab> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  _StaffEntryMode _mode = _StaffEntryMode.create;
  String _role = UserRoleCode.receptionist.apiValue;
  bool _submitting = false;
  String? _updatingAssignmentId;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _fullName.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _submitting = true);
    try {
      if (_mode == _StaffEntryMode.create) {
        await ref.read(operationsApiProvider).createStaff(
              hotelId: widget.hotelId,
              request: CreateStaffRequest(
                email: _email.text,
                password: _password.text,
                fullName: _fullName.text,
                phoneNumber: _phone.text,
                role: _role,
              ),
            );
      } else {
        await ref.read(operationsApiProvider).attachStaff(
              hotelId: widget.hotelId,
              request: AttachStaffRequest(
                email: _email.text,
                role: _role,
              ),
            );
      }

      _email.clear();
      _password.clear();
      _fullName.clear();
      _phone.clear();
      ref.invalidate(hotelStaffProvider(widget.hotelId));
      if (mounted) {
        AppErrorPresenter.showSnackBar(
          context,
          _mode == _StaffEntryMode.create
              ? 'Staff account created and assigned.'
              : 'Existing account assigned to this hotel.',
        );
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

  Future<void> _updateAssignment(
    HotelStaffMember member,
    UpdateStaffAssignmentRequest request,
    String successMessage,
  ) async {
    setState(() => _updatingAssignmentId = member.assignmentId);
    try {
      await ref.read(operationsApiProvider).updateStaffAssignment(
            hotelId: widget.hotelId,
            assignmentId: member.assignmentId,
            request: request,
          );
      ref.invalidate(hotelStaffProvider(widget.hotelId));
      if (mounted) {
        AppErrorPresenter.showSnackBar(context, successMessage);
      }
    } catch (error) {
      if (mounted) {
        await AppErrorPresenter.showBottomSheet(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _updatingAssignmentId = null);
      }
    }
  }

  Future<void> _chooseRole(
    HotelStaffMember member,
    List<String> availableRoles,
  ) async {
    String selectedRole = member.role;
    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.xl,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Change hotel role',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text('Update access for ${member.fullName}.'),
                    const SizedBox(height: AppSpacing.lg),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRole,
                      decoration: const InputDecoration(labelText: 'Role'),
                      items: [
                        for (final role in availableRoles)
                          DropdownMenuItem(
                            value: role,
                            child: Text(_roleLabel(role)),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setModalState(() => selectedRole = value);
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton(
                      onPressed: selectedRole == member.role
                          ? null
                          : () => Navigator.of(context).pop(selectedRole),
                      child: const Text('Save role'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result != null && mounted) {
      await _updateAssignment(
        member,
        UpdateStaffAssignmentRequest(role: result),
        'Hotel role updated.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider).userSession;
    final isOwner = session?.roles.contains(
          UserRoleCode.propertyOwner.apiValue,
        ) ??
        false;
    final availableRoles = <String>[
      if (isOwner) UserRoleCode.hotelManager.apiValue,
      UserRoleCode.receptionist.apiValue,
      UserRoleCode.housekeepingStaff.apiValue,
      UserRoleCode.maintenanceStaff.apiValue,
    ];
    if (!availableRoles.contains(_role)) {
      _role = UserRoleCode.receptionist.apiValue;
    }
    final staff = ref.watch(hotelStaffProvider(widget.hotelId));

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(hotelStaffProvider(widget.hotelId)),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text('Staff access', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            isOwner
                ? 'Create or attach accounts, assign hotel roles, and control access.'
                : 'Manage operational staff assigned to your working hotel.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          _StaffEntryCard(
            formKey: _formKey,
            mode: _mode,
            email: _email,
            password: _password,
            fullName: _fullName,
            phone: _phone,
            role: _role,
            availableRoles: availableRoles,
            submitting: _submitting,
            onModeChanged: (value) => setState(() => _mode = value),
            onRoleChanged: (value) => setState(() => _role = value),
            onSubmit: _submit,
          ),
          const SizedBox(height: AppSpacing.md),
          staff.when(
            data: (items) {
              if (items.isEmpty) {
                return const _EmptyStaff();
              }

              return Column(
                children: [
                  for (final item in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _StaffCard(
                        member: item,
                        busy: _updatingAssignmentId == item.assignmentId,
                        canManage: isOwner ||
                            (item.role != UserRoleCode.hotelManager.apiValue &&
                                item.userAccountId != session?.userId),
                        availableRoles: availableRoles,
                        onChangeRole: () => _chooseRole(item, availableRoles),
                        onToggleAccess: () => _updateAssignment(
                          item,
                          UpdateStaffAssignmentRequest(
                            isActive: !item.isAssignmentActive,
                          ),
                          item.isAssignmentActive
                              ? 'Hotel access paused.'
                              : 'Hotel access restored.',
                        ),
                      ),
                    ),
                ],
              );
            },
            error: (error, stackTrace) => _StaffError(
              onRetry: () => ref.invalidate(hotelStaffProvider(widget.hotelId)),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
    );
  }
}

class _StaffEntryCard extends StatelessWidget {
  const _StaffEntryCard({
    required this.formKey,
    required this.mode,
    required this.email,
    required this.password,
    required this.fullName,
    required this.phone,
    required this.role,
    required this.availableRoles,
    required this.submitting,
    required this.onModeChanged,
    required this.onRoleChanged,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final _StaffEntryMode mode;
  final TextEditingController email;
  final TextEditingController password;
  final TextEditingController fullName;
  final TextEditingController phone;
  final String role;
  final List<String> availableRoles;
  final bool submitting;
  final ValueChanged<_StaffEntryMode> onModeChanged;
  final ValueChanged<String> onRoleChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final createsAccount = mode == _StaffEntryMode.create;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<_StaffEntryMode>(
                segments: const [
                  ButtonSegment(
                    value: _StaffEntryMode.create,
                    icon: Icon(Icons.person_add_alt_1_rounded),
                    label: Text('Create account'),
                  ),
                  ButtonSegment(
                    value: _StaffEntryMode.attach,
                    icon: Icon(Icons.link_rounded),
                    label: Text('Attach existing'),
                  ),
                ],
                selected: {mode},
                onSelectionChanged: (selection) {
                  onModeChanged(selection.first);
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              if (createsAccount) ...[
                AppTextFormField(
                  controller: fullName,
                  labelText: 'Full name',
                  validator: (value) =>
                      (value == null || value.trim().length < 2)
                          ? 'Enter the staff member full name.'
                          : null,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              AppTextFormField(
                controller: email,
                labelText: createsAccount ? 'Work email' : 'Existing email',
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  final text = value?.trim() ?? '';
                  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)
                      ? null
                      : 'Enter a valid email address.';
                },
              ),
              if (createsAccount) ...[
                const SizedBox(height: AppSpacing.md),
                AppTextFormField(
                  controller: phone,
                  labelText: 'Phone number',
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    return RegExp(r'^\d{10}$').hasMatch(text)
                        ? null
                        : 'Phone number must contain 10 digits.';
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextFormField(
                  controller: password,
                  labelText: 'Initial password',
                  obscureText: true,
                  validator: (value) => (value == null || value.length < 8)
                      ? 'Password must have at least 8 characters.'
                      : null,
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: role,
                decoration: const InputDecoration(labelText: 'Hotel role'),
                items: [
                  for (final value in availableRoles)
                    DropdownMenuItem(
                      value: value,
                      child: Text(_roleLabel(value)),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    onRoleChanged(value);
                  }
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: submitting ? null : onSubmit,
                icon: submitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        createsAccount
                            ? Icons.person_add_alt_1_rounded
                            : Icons.link_rounded,
                      ),
                label: Text(
                  createsAccount ? 'Create and assign' : 'Assign account',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StaffCard extends StatelessWidget {
  const _StaffCard({
    required this.member,
    required this.busy,
    required this.canManage,
    required this.availableRoles,
    required this.onChangeRole,
    required this.onToggleAccess,
  });

  final HotelStaffMember member;
  final bool busy;
  final bool canManage;
  final List<String> availableRoles;
  final VoidCallback onChangeRole;
  final VoidCallback onToggleAccess;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: member.isAssignmentActive
                      ? AppColors.brand
                      : Theme.of(context).colorScheme.outline,
                  foregroundColor: Colors.white,
                  child: Text(_initials(member.fullName, member.email)),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.fullName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(member.email),
                      if (member.phoneNumber?.isNotEmpty == true)
                        Text(member.phoneNumber!),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                _StaffPill(
                  label: _roleLabel(member.role),
                  color: AppColors.brand,
                ),
                _StaffPill(
                  label: member.isAssignmentActive
                      ? 'Hotel access active'
                      : 'Hotel access paused',
                  color: member.isAssignmentActive
                      ? AppColors.success
                      : AppColors.warning,
                ),
                if (member.status != 'Active')
                  _StaffPill(
                    label: 'Account ${member.status.toLowerCase()}',
                    color: AppColors.danger,
                  ),
              ],
            ),
            if (canManage) ...[
              const SizedBox(height: AppSpacing.md),
              const Divider(),
              if (busy)
                const Center(child: CircularProgressIndicator())
              else
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  alignment: WrapAlignment.end,
                  children: [
                    if (member.isAssignmentActive &&
                        availableRoles.any((role) => role != member.role))
                      OutlinedButton.icon(
                        onPressed: onChangeRole,
                        icon: const Icon(Icons.manage_accounts_rounded),
                        label: const Text('Change role'),
                      ),
                    FilledButton.tonalIcon(
                      onPressed: onToggleAccess,
                      icon: Icon(
                        member.isAssignmentActive
                            ? Icons.pause_circle_outline_rounded
                            : Icons.play_circle_outline_rounded,
                      ),
                      label: Text(
                        member.isAssignmentActive
                            ? 'Pause access'
                            : 'Restore access',
                      ),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StaffPill extends StatelessWidget {
  const _StaffPill({required this.label, required this.color});

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

class _EmptyStaff extends StatelessWidget {
  const _EmptyStaff();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Text('No staff accounts are assigned to this hotel yet.'),
      ),
    );
  }
}

class _StaffError extends StatelessWidget {
  const _StaffError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            const Text('Unable to load staff accounts.'),
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

String _roleLabel(String role) {
  return switch (role) {
    'HotelManager' => 'Hotel manager',
    'Receptionist' => 'Receptionist',
    'HousekeepingStaff' => 'Housekeeping staff',
    'MaintenanceStaff' => 'Maintenance staff',
    _ => role,
  };
}

String _initials(String fullName, String email) {
  final parts = fullName
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.length >= 2) {
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
  if (parts.length == 1) {
    return parts.first[0].toUpperCase();
  }
  return email.isEmpty ? '?' : email[0].toUpperCase();
}
