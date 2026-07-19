import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../shared/widgets/app_error_presenter.dart';
import '../../../shared/widgets/app_text_form_field.dart';
import '../../auth/presentation/auth_form_validators.dart';
import '../../customer/application/customer_account_providers.dart';
import '../../customer/domain/customer_account_models.dart';

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
  final _passwordFormKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _hydrated = false;
  bool _savingProfile = false;
  bool _changingPassword = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
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
        AppErrorPresenter.showSnackBar(context, 'Account profile updated.');
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

  Future<void> _changePassword() async {
    FocusScope.of(context).unfocus();
    if (_passwordFormKey.currentState?.validate() != true) {
      return;
    }
    setState(() => _changingPassword = true);
    try {
      await ref.read(customerAccountApiProvider).changePassword(
            ChangeCustomerPasswordRequest(
              currentPassword: _currentPassword.text,
              newPassword: _newPassword.text,
              confirmNewPassword: _confirmPassword.text,
            ),
          );
      _currentPassword.clear();
      _newPassword.clear();
      _confirmPassword.clear();
      if (mounted) {
        AppErrorPresenter.showSnackBar(context, 'Password updated.');
      }
    } catch (error) {
      if (mounted) {
        await AppErrorPresenter.showBottomSheet(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _changingPassword = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(customerProfileProvider);
    profile.whenData((value) {
      if (!_hydrated) {
        _hydrated = true;
        _name.text = value.fullName;
        _phone.text = value.phoneNumber ?? '';
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Account settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Form(
                  key: _profileFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Profile',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      profile.when(
                        data: (value) => Text(value.email),
                        loading: () => const LinearProgressIndicator(),
                        error: (error, stackTrace) => Text(
                          AppErrorPresenter.friendlyMessage(error),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppTextFormField(
                        controller: _name,
                        labelText: 'Full name',
                        prefixIcon: const Icon(Icons.person_outline_rounded),
                        validator: AuthFormValidators.fullName,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextFormField(
                        controller: _phone,
                        labelText: 'Phone number',
                        prefixIcon: const Icon(Icons.phone_outlined),
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        validator: AuthFormValidators.phoneNumber,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      FilledButton.icon(
                        onPressed: _savingProfile ? null : _saveProfile,
                        icon: _savingProfile
                            ? const SizedBox.square(
                                dimension: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save_rounded),
                        label: Text(_savingProfile ? 'Saving' : 'Save profile'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Form(
                  key: _passwordFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Security',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppTextFormField(
                        controller: _currentPassword,
                        labelText: 'Current password',
                        obscureText: true,
                        validator: AuthFormValidators.password,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextFormField(
                        controller: _newPassword,
                        labelText: 'New password',
                        obscureText: true,
                        validator: (value) => AuthFormValidators.password(
                          value,
                          strong: true,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextFormField(
                        controller: _confirmPassword,
                        labelText: 'Confirm new password',
                        obscureText: true,
                        validator: (value) => value != _newPassword.text
                            ? 'Passwords do not match.'
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      FilledButton.icon(
                        onPressed: _changingPassword ? null : _changePassword,
                        icon: _changingPassword
                            ? const SizedBox.square(
                                dimension: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.password_rounded),
                        label: Text(
                          _changingPassword ? 'Updating' : 'Change password',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
