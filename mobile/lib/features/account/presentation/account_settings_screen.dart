import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../shared/widgets/app_error_presenter.dart';
import '../../../shared/widgets/app_text_form_field.dart';
import '../../../shared/widgets/srs_screen.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../auth/presentation/auth_form_validators.dart';
import '../../customer/application/customer_account_providers.dart';
import '../../customer/domain/customer_account_models.dart';
import '../../operations/application/operations_providers.dart';
import '../../operations/domain/operations_models.dart';

class AccountSettingsScreen extends ConsumerStatefulWidget {
  const AccountSettingsScreen({super.key});

  static const String routeName = 'account-settings';
  static const String routePath = '/account';

  @override
  ConsumerState<AccountSettingsScreen> createState() =>
      _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends ConsumerState<AccountSettingsScreen> {
  final _profileFormKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _hydrated = false;
  bool _savingProfile = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    FocusScope.of(context).unfocus();
    if (_profileFormKey.currentState?.validate() != true) {
      return;
    }

    setState(() => _savingProfile = true);
    try {
      await ref.read(customerAccountApiProvider).updateProfile(
            UpdateCustomerProfileRequest(
              fullName: _name.text,
              phoneNumber: _phone.text,
            ),
          );
      ref.invalidate(customerProfileProvider);
      if (mounted) {
        AppErrorPresenter.showSnackBar(
          context,
          'Your profile has been updated successfully.',
        );
      }
    } catch (error) {
      if (mounted) {
        await AppErrorPresenter.showBottomSheet(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _savingProfile = false);
      }
    }
  }

  Future<void> _openSecuritySheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const _ChangePasswordSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(customerProfileProvider);
    final workingHotels = ref.watch(workingHotelsProvider);
    final session = ref.watch(authControllerProvider).userSession;

    profile.whenData((value) {
      if (!_hydrated) {
        _hydrated = true;
        _name.text = value.fullName;
        _phone.text = value.phoneNumber ?? '';
      }
    });

    return SrsScreen(
      title: 'User Profile Screen',
      actions: [
        PopupMenuButton<_ProfileAction>(
          tooltip: 'Account actions',
          onSelected: (action) {
            switch (action) {
              case _ProfileAction.changePassword:
                _openSecuritySheet();
              case _ProfileAction.signOut:
                ref.read(authControllerProvider.notifier).logout();
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: _ProfileAction.changePassword,
              child: Text('Change password'),
            ),
            PopupMenuItem(
              value: _ProfileAction.signOut,
              child: Text('Sign out'),
            ),
          ],
        ),
      ],
      child: Form(
        key: _profileFormKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextFormField(
              controller: _name,
              labelText: 'Full Name',
              externalLabel: true,
              required: true,
              validator: AuthFormValidators.fullName,
            ),
            const SizedBox(height: AppSpacing.lg),
            _ReadOnlySrsField(
              label: 'Email',
              value: profile.valueOrNull?.email ?? session?.email ?? '',
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextFormField(
              controller: _phone,
              labelText: 'Phone Number',
              externalLabel: true,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              validator: AuthFormValidators.phoneNumber,
            ),
            const SizedBox(height: AppSpacing.lg),
            _ReadOnlySrsField(
              label: 'Role',
              value: _roleLabels(session?.roles),
              showDropdownIndicator: true,
            ),
            const SizedBox(height: AppSpacing.lg),
            const SrsSectionTitle('Hotel Assignments'),
            const SizedBox(height: AppSpacing.sm),
            _HotelAssignments(
              hotels: workingHotels.valueOrNull ?? const [],
              hotelIds: session?.hotelIds ?? const [],
              isLoading: workingHotels.isLoading,
            ),
            if (profile.hasError) ...[
              const SizedBox(height: AppSpacing.md),
              Text(AppErrorPresenter.friendlyMessage(profile.error!)),
            ],
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _savingProfile ? null : _saveProfile,
              child: _savingProfile
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ProfileAction { changePassword, signOut }

class _ReadOnlySrsField extends StatelessWidget {
  const _ReadOnlySrsField({
    required this.label,
    required this.value,
    this.showDropdownIndicator = false,
  });

  final String label;
  final String value;
  final bool showDropdownIndicator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SrsFieldLabel(label),
        InputDecorator(
          decoration: const InputDecoration(),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (showDropdownIndicator)
                const Icon(Icons.arrow_drop_down, color: AppColors.mutedInk),
            ],
          ),
        ),
      ],
    );
  }
}

class _HotelAssignments extends StatelessWidget {
  const _HotelAssignments({
    required this.hotels,
    required this.hotelIds,
    required this.isLoading,
  });

  final List<WorkingHotel> hotels;
  final List<String> hotelIds;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const LinearProgressIndicator();
    }

    if (hotelIds.isEmpty) {
      return const SrsPanel(child: Text('No hotel assignments'));
    }

    final hotelsById = {for (final hotel in hotels) hotel.id: hotel};
    return Column(
      children: [
        for (var index = 0; index < hotelIds.length; index++) ...[
          SrsPanel(
            child: Builder(
              builder: (context) {
                final hotel = hotelsById[hotelIds[index]];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hotel?.displayName ?? 'Assigned hotel',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      hotel?.subtitle ?? hotelIds[index],
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                );
              },
            ),
          ),
          if (index < hotelIds.length - 1)
            const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _ChangePasswordSheet extends ConsumerStatefulWidget {
  const _ChangePasswordSheet();

  @override
  ConsumerState<_ChangePasswordSheet> createState() =>
      _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends ConsumerState<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(customerAccountApiProvider).changePassword(
            ChangeCustomerPasswordRequest(
              currentPassword: _currentPassword.text,
              newPassword: _newPassword.text,
              confirmNewPassword: _confirmPassword.text,
            ),
          );
      if (mounted) {
        Navigator.of(context).pop();
        AppErrorPresenter.showSnackBar(context, 'Password updated.');
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
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Change password',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextFormField(
              controller: _currentPassword,
              labelText: 'Current Password',
              externalLabel: true,
              obscureText: true,
              validator: AuthFormValidators.password,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextFormField(
              controller: _newPassword,
              labelText: 'New Password',
              externalLabel: true,
              obscureText: true,
              validator: (value) =>
                  AuthFormValidators.password(value, strong: true),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextFormField(
              controller: _confirmPassword,
              labelText: 'Confirm New Password',
              externalLabel: true,
              obscureText: true,
              validator: (value) =>
                  value != _newPassword.text ? 'Passwords do not match.' : null,
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Change password'),
            ),
          ],
        ),
      ),
    );
  }
}

String _roleLabels(List<String>? roles) {
  if (roles == null || roles.isEmpty) {
    return 'No role assigned';
  }

  return roles.map((value) {
    final role = UserRoleCode.fromApiValue(value);
    return switch (role) {
      UserRoleCode.customer => 'Customer',
      UserRoleCode.propertyOwner => 'Property Owner',
      UserRoleCode.hotelManager => 'Hotel Manager',
      UserRoleCode.receptionist => 'Receptionist',
      UserRoleCode.housekeepingStaff => 'Housekeeping Staff',
      UserRoleCode.maintenanceStaff => 'Maintenance Staff',
      UserRoleCode.platformAdministrator => 'Platform Administrator',
    };
  }).join(', ');
}
