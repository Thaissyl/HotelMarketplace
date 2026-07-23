import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../shared/widgets/app_error_presenter.dart';
import '../../../shared/widgets/app_text_form_field.dart';
import '../application/auth_controller.dart';
import '../application/auth_state.dart';
import '../domain/auth_models.dart';
import 'auth_form_validators.dart';
import 'auth_shell.dart';
import 'auth_submit_button.dart';
import 'login_screen.dart';
import 'password_field.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  static const String routeName = 'register';
  static const String routePath = '/register';

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  UserRoleCode _role = UserRoleCode.customer;
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    final success = await ref.read(authControllerProvider.notifier).register(
          email: _emailController.text,
          password: _passwordController.text,
          fullName: _fullNameController.text,
          phoneNumber: _phoneController.text,
          role: _role,
        );

    if (!success && mounted) {
      final error = ref.read(authControllerProvider).error;
      if (error != null) {
        await AppErrorPresenter.showBottomSheet(context, error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.status == AuthStatus.authenticating;

    return AuthShell(
      title: 'Register',
      subtitle: 'Start as a traveler or register as a property owner.',
      showBackButton: false,
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Account type',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            RadioGroup<UserRoleCode>(
              groupValue: _role,
              onChanged: (value) {
                if (!isLoading && value != null) {
                  setState(() => _role = value);
                }
              },
              child: const Column(
                children: [
                  RadioListTile<UserRoleCode>(
                    contentPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    title: Text('Customer'),
                    value: UserRoleCode.customer,
                  ),
                  RadioListTile<UserRoleCode>(
                    contentPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    title: Text('Property Owner'),
                    value: UserRoleCode.propertyOwner,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextFormField(
              controller: _fullNameController,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              validator: AuthFormValidators.fullName,
              labelText: 'Full name',
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              validator: AuthFormValidators.email,
              labelText: 'Email',
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              validator: AuthFormValidators.phoneNumber,
              labelText: 'Phone number (optional)',
            ),
            const SizedBox(height: AppSpacing.md),
            PasswordField(
              controller: _passwordController,
              textInputAction: TextInputAction.next,
              validator: (value) => AuthFormValidators.password(
                value,
                strong: true,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            PasswordField(
              controller: _confirmPasswordController,
              labelText: 'Confirm password',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Confirm your password.';
                }
                if (value != _passwordController.text) {
                  return 'Passwords do not match.';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            FormField<bool>(
              initialValue: _acceptedTerms,
              validator: (value) =>
                  value == true ? null : 'Accept the terms to continue.',
              builder: (field) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _acceptedTerms,
                      title: const Text(
                        'I accept the terms',
                      ),
                      onChanged: isLoading
                          ? null
                          : (value) {
                              setState(() => _acceptedTerms = value ?? false);
                              field.didChange(_acceptedTerms);
                            },
                    ),
                    if (field.hasError)
                      Padding(
                        padding: const EdgeInsets.only(left: AppSpacing.sm),
                        child: Text(
                          field.errorText!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.xl),
            AuthSubmitButton(
              label: 'Register',
              isLoading: isLoading,
              onPressed: _submit,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextButton(
              onPressed: isLoading
                  ? null
                  : () {
                      context.go(LoginScreen.routePath);
                    },
              child: const Text('I already have an account'),
            ),
          ],
        ),
      ),
    );
  }
}
