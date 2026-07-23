import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/widgets/app_error_presenter.dart';
import '../../../shared/widgets/app_text_form_field.dart';
import '../application/auth_controller.dart';
import '../application/auth_state.dart';
import 'auth_form_validators.dart';
import 'auth_shell.dart';
import 'auth_submit_button.dart';
import 'password_field.dart';
import 'register_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  static const String routeName = 'login';
  static const String routePath = '/login';

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    final success = await ref.read(authControllerProvider.notifier).login(
          email: _emailController.text,
          password: _passwordController.text,
        );

    if (!success && mounted) {
      final error = ref.read(authControllerProvider).error;
      if (error != null) {
        await AppErrorPresenter.showBottomSheet(
          context,
          error is UnauthorizedApiException
              ? 'Email or password is incorrect. Please check your credentials and try again.'
              : error,
          title: error is UnauthorizedApiException
              ? 'Incorrect email or password'
              : null,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.status == AuthStatus.authenticating;

    return AuthShell(
      title: 'Login Screen',
      subtitle: 'Sign in with your registered email.',
      showBackButton: false,
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              validator: AuthFormValidators.email,
              labelText: 'Email',
            ),
            const SizedBox(height: AppSpacing.md),
            PasswordField(
              controller: _passwordController,
              validator: AuthFormValidators.password,
              onFieldSubmitted: (_) => isLoading ? null : _submit(),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: isLoading
                    ? null
                    : () => showDialog<void>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Password recovery'),
                            content: const Text(
                              'Password recovery is not available in this MVP. '
                              'Contact the property owner or platform administrator '
                              'to restore access to a managed account.',
                            ),
                            actions: [
                              FilledButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        ),
                child: const Text('Forgot password?'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AuthSubmitButton(
              label: 'Login',
              isLoading: isLoading,
              onPressed: _submit,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextButton(
              onPressed: isLoading
                  ? null
                  : () {
                      context.go(RegisterScreen.routePath);
                    },
              child: const Text('Register'),
            ),
          ],
        ),
      ),
    );
  }
}
