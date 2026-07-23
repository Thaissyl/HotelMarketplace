import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../shared/widgets/app_error_presenter.dart';
import '../application/operations_providers.dart';
import '../domain/operations_models.dart';
import 'front_desk_components.dart';
import 'staff_components.dart';

enum _StaffEntryMode { create, attach }

class StaffEntryScreen extends ConsumerStatefulWidget {
  const StaffEntryScreen({
    super.key,
    required this.hotelId,
    required this.availableRoles,
  });

  final String hotelId;
  final List<String> availableRoles;

  @override
  ConsumerState<StaffEntryScreen> createState() => _StaffEntryScreenState();
}

class _StaffEntryScreenState extends ConsumerState<StaffEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  _StaffEntryMode _mode = _StaffEntryMode.create;
  late String _role;
  bool _submitting = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _role = widget.availableRoles.first;
  }

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
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
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        await AppErrorPresenter.showBottomSheet(
          context,
          error,
          title: _mode == _StaffEntryMode.create
              ? 'Staff account not created'
              : 'Staff account not attached',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final createsAccount = _mode == _StaffEntryMode.create;
    return FrontDeskRouteScaffold(
      title: 'Invite/Create Staff',
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            SegmentedButton<_StaffEntryMode>(
              segments: const [
                ButtonSegment(
                  value: _StaffEntryMode.create,
                  label: Text('Create Account'),
                  icon: Icon(Icons.person_add_alt_1_outlined),
                ),
                ButtonSegment(
                  value: _StaffEntryMode.attach,
                  label: Text('Attach Existing'),
                  icon: Icon(Icons.link_outlined),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: _submitting
                  ? null
                  : (selection) => setState(() => _mode = selection.first),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (createsAccount) ...[
              const FrontDeskFieldLabel('Full Name'),
              TextFormField(
                controller: _fullName,
                enabled: !_submitting,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.length < 2 || text.length > 200) {
                    return 'Enter the staff member full name.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            FrontDeskFieldLabel(
              createsAccount ? 'Work Email' : 'Existing Account Email',
            ),
            TextFormField(
              controller: _email,
              enabled: !_submitting,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: (value) {
                final text = value?.trim() ?? '';
                return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)
                    ? null
                    : 'Enter a valid email address.';
              },
            ),
            if (createsAccount) ...[
              const SizedBox(height: AppSpacing.lg),
              const FrontDeskFieldLabel('Phone Number'),
              TextFormField(
                controller: _phone,
                enabled: !_submitting,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: (value) {
                  return RegExp(r'^\d{10}$').hasMatch(value?.trim() ?? '')
                      ? null
                      : 'Phone number must contain 10 digits.';
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              const FrontDeskFieldLabel('Initial Password'),
              TextFormField(
                controller: _password,
                enabled: !_submitting,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    onPressed: () => setState(
                      () => _obscurePassword = !_obscurePassword,
                    ),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (value) {
                  final text = value ?? '';
                  if (text.length < 8) {
                    return 'Password must contain at least 8 characters.';
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            const FrontDeskFieldLabel('Staff Role'),
            DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.admin_panel_settings_outlined),
              ),
              items: [
                for (final role in widget.availableRoles)
                  DropdownMenuItem(
                    value: role,
                    child: Text(staffRoleLabel(role)),
                  ),
              ],
              onChanged: _submitting
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _role = value);
                      }
                    },
            ),
            const SizedBox(height: AppSpacing.lg),
            StaffPermissionSummary(role: _role),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        createsAccount
                            ? 'Create and Assign Staff'
                            : 'Attach Staff Account',
                      ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}
