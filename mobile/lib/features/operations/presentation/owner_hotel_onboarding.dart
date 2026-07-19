import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../shared/widgets/app_error_presenter.dart';
import '../../../shared/widgets/app_text_form_field.dart';
import '../application/operations_providers.dart';
import '../application/selected_hotel_controller.dart';
import '../domain/operations_models.dart';

class OwnerHotelOnboarding extends ConsumerStatefulWidget {
  const OwnerHotelOnboarding({super.key});

  @override
  ConsumerState<OwnerHotelOnboarding> createState() =>
      _OwnerHotelOnboardingState();
}

class _OwnerHotelOnboardingState extends ConsumerState<OwnerHotelOnboarding> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _city = TextEditingController();
  final _address = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _description = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _address.dispose();
    _email.dispose();
    _phone.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    setState(() => _submitting = true);
    try {
      final hotel = await ref.read(operationsApiProvider).registerHotel(
            RegisterHotelRequest(
              name: _name.text,
              city: _city.text,
              addressLine: _address.text,
              contactEmail: _email.text,
              contactPhone: _phone.text,
              description: _description.text,
            ),
          );
      await ref
          .read(selectedHotelControllerProvider.notifier)
          .addAndSelectHotel(hotel.id);
      ref.invalidate(workingHotelsProvider);
      if (mounted) {
        AppErrorPresenter.showSnackBar(
          context,
          'Hotel registered and submitted for platform review.',
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

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required.';
    }
    return null;
  }

  String? _emailValidator(String? value) {
    final requiredError = _required(value);
    if (requiredError != null) {
      return requiredError;
    }
    final emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return emailPattern.hasMatch(value!.trim())
        ? null
        : 'Enter a valid email address.';
  }

  String? _phoneValidator(String? value) {
    final normalized = value?.replaceAll(RegExp(r'\D'), '') ?? '';
    return normalized.length == 10
        ? null
        : 'Phone number must contain exactly 10 digits.';
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Icon(
          Icons.add_business_rounded,
          size: 48,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Register your first hotel',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'The property will remain private until a platform administrator approves it.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xl),
        Form(
          key: _formKey,
          child: Column(
            children: [
              AppTextFormField(
                controller: _name,
                labelText: 'Hotel name',
                validator: _required,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextFormField(
                controller: _city,
                labelText: 'City',
                validator: _required,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextFormField(
                controller: _address,
                labelText: 'Street address',
                validator: _required,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextFormField(
                controller: _email,
                labelText: 'Contact email',
                keyboardType: TextInputType.emailAddress,
                validator: _emailValidator,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextFormField(
                controller: _phone,
                labelText: 'Contact phone',
                keyboardType: TextInputType.phone,
                validator: _phoneValidator,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextFormField(
                controller: _description,
                labelText: 'Property description',
                maxLines: 4,
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(
                    _submitting ? 'Submitting' : 'Submit for review',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
