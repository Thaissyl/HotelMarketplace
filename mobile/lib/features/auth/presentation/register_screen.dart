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
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  UserRoleCode _role = UserRoleCode.customer;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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
      title: 'Create account',
      subtitle: 'Start as a traveler or register as a property owner.',
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextFormField(
              controller: _fullNameController,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              validator: AuthFormValidators.fullName,
              labelText: 'Full name',
              prefixIcon: const Icon(Icons.person_outline_rounded),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              validator: AuthFormValidators.email,
              labelText: 'Email',
              prefixIcon: const Icon(Icons.mail_outline_rounded),
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
              labelText: 'Phone number',
              prefixIcon: const Icon(Icons.phone_outlined),
            ),
            const SizedBox(height: AppSpacing.md),
            PasswordField(
              controller: _passwordController,
              validator: (value) => AuthFormValidators.password(
                value,
                strong: true,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SegmentedButton<UserRoleCode>(
              segments: const [
                ButtonSegment(
                  value: UserRoleCode.customer,
                  label: Text('Customer'),
                  icon: Icon(Icons.luggage_rounded),
                ),
                ButtonSegment(
                  value: UserRoleCode.propertyOwner,
                  label: Text('Owner'),
                  icon: Icon(Icons.apartment_rounded),
                ),
              ],
              selected: {_role},
              onSelectionChanged: isLoading
                  ? null
                  : (selection) {
                      setState(() {
                        _role = selection.first;
                      });
                    },
            ),
            const SizedBox(height: AppSpacing.xl),
            AuthSubmitButton(
              label: 'Create account',
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
