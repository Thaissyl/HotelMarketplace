import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../shared/widgets/app_error_presenter.dart';
import '../../../shared/widgets/app_text_form_field.dart';
import '../application/operations_providers.dart';
import '../domain/operations_models.dart';

class StaffManagementTab extends ConsumerStatefulWidget {
  const StaffManagementTab({super.key, required this.hotelId});

  final String hotelId;

  @override
  ConsumerState<StaffManagementTab> createState() => _StaffManagementTabState();
}

class _StaffManagementTabState extends ConsumerState<StaffManagementTab> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController(text: 'Test@123');
  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  String _role = 'Receptionist';
  bool _submitting = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _fullName.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _createStaff() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _submitting = true);
    try {
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
      _email.clear();
      _fullName.clear();
      _phone.clear();
      ref.invalidate(hotelStaffProvider(widget.hotelId));
      if (mounted) {
        AppErrorPresenter.showSnackBar(context, 'Staff account created.');
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
    final staff = ref.watch(hotelStaffProvider(widget.hotelId));

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(hotelStaffProvider(widget.hotelId)),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            'Staff management',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Create hotel staff accounts and assign them to the selected working hotel.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          _CreateStaffCard(
            formKey: _formKey,
            email: _email,
            password: _password,
            fullName: _fullName,
            phone: _phone,
            role: _role,
            submitting: _submitting,
            onRoleChanged: (value) => setState(() => _role = value),
            onSubmit: _createStaff,
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
                      child: _StaffCard(member: item),
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

class _CreateStaffCard extends StatelessWidget {
  const _CreateStaffCard({
    required this.formKey,
    required this.email,
    required this.password,
    required this.fullName,
    required this.phone,
    required this.role,
    required this.submitting,
    required this.onRoleChanged,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController email;
  final TextEditingController password;
  final TextEditingController fullName;
  final TextEditingController phone;
  final String role;
  final bool submitting;
  final ValueChanged<String> onRoleChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Add staff member',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextFormField(
                controller: fullName,
                labelText: 'Full name',
                validator: (value) => (value == null || value.trim().length < 2)
                    ? 'Enter staff full name.'
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextFormField(
                controller: email,
                labelText: 'Email',
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  final text = value?.trim() ?? '';
                  return text.contains('@') ? null : 'Enter a valid email.';
                },
              ),
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
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: role,
                decoration: const InputDecoration(labelText: 'Hotel role'),
                items: const [
                  DropdownMenuItem(
                    value: 'HotelManager',
                    child: Text('Hotel manager'),
                  ),
                  DropdownMenuItem(
                    value: 'Receptionist',
                    child: Text('Receptionist'),
                  ),
                  DropdownMenuItem(
                    value: 'HousekeepingStaff',
                    child: Text('Housekeeping staff'),
                  ),
                  DropdownMenuItem(
                    value: 'MaintenanceStaff',
                    child: Text('Maintenance staff'),
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
                    : const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Create and assign'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StaffCard extends StatelessWidget {
  const _StaffCard({required this.member});

  final HotelStaffMember member;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.brand,
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
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.sm,
                    children: [
                      _StaffPill(
                        label: _roleLabel(member.role),
                        color: AppColors.brand,
                      ),
                      _StaffPill(
                        label: member.status,
                        color: _statusColor(member.status),
                      ),
                    ],
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
        child: Text('No staff accounts have been assigned to this hotel yet.'),
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
    'HousekeepingStaff' => 'Housekeeping',
    'MaintenanceStaff' => 'Maintenance',
    _ => role,
  };
}

Color _statusColor(String status) {
  return status == 'Active' ? AppColors.success : AppColors.warning;
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
