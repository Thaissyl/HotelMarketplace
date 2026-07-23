import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../shared/widgets/app_error_presenter.dart';
import '../../../shared/widgets/app_text_form_field.dart';
import '../../../shared/widgets/srs_screen.dart';
import '../application/operations_providers.dart';
import '../domain/operations_models.dart';
import 'owner_hotel_content_card.dart';

class OwnerPropertyTab extends ConsumerWidget {
  const OwnerPropertyTab({super.key, required this.hotelId});

  final String hotelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hotel = ref.watch(ownerHotelProvider(hotelId));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(ownerHotelProvider(hotelId));
        ref.invalidate(hotelContentProvider(hotelId));
      },
      child: hotel.when(
        loading: () => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 240),
            Center(child: CircularProgressIndicator()),
          ],
        ),
        error: (error, stackTrace) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            _ErrorPanel(
              error: error,
              onRetry: () => ref.invalidate(ownerHotelProvider(hotelId)),
            ),
          ],
        ),
        data: (value) => _HotelProfileEditor(
          key: ValueKey('${value.id}-${value.approvalStatus}'),
          hotelId: hotelId,
          hotel: value,
        ),
      ),
    );
  }
}

class _HotelProfileEditor extends ConsumerStatefulWidget {
  const _HotelProfileEditor({
    super.key,
    required this.hotelId,
    required this.hotel,
  });

  final String hotelId;
  final WorkingHotel hotel;

  @override
  ConsumerState<_HotelProfileEditor> createState() =>
      _HotelProfileEditorState();
}

class _HotelProfileEditorState extends ConsumerState<_HotelProfileEditor> {
  final _formKey = GlobalKey<FormState>();
  final _contentKey = GlobalKey<OwnerHotelContentCardState>();
  late final TextEditingController _name;
  late final TextEditingController _city;
  late final TextEditingController _address;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _description;
  late bool _requiresRoomInspection;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.hotel.name);
    _city = TextEditingController(text: widget.hotel.city);
    _address = TextEditingController(text: widget.hotel.addressLine);
    _email = TextEditingController(text: widget.hotel.contactEmail);
    _phone = TextEditingController(text: widget.hotel.contactPhone);
    _description = TextEditingController(text: widget.hotel.description);
    _requiresRoomInspection = widget.hotel.requiresRoomInspection;
  }

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

  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    final contentState = _contentKey.currentState;
    if (contentState == null) {
      AppErrorPresenter.showSnackBar(
        context,
        'Hotel content is still loading.',
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final contentSaved = await contentState.saveContent(showFeedback: false);
      if (!contentSaved || !mounted) {
        return;
      }

      await ref.read(operationsApiProvider).updateOwnerHotel(
            hotelId: widget.hotelId,
            request: UpdateHotelProfileRequest(
              name: _name.text,
              city: _city.text,
              addressLine: _address.text,
              contactEmail: _email.text,
              contactPhone: _phone.text,
              description: _description.text,
              requiresRoomInspection: _requiresRoomInspection,
            ),
          );
      ref.invalidate(ownerHotelProvider(widget.hotelId));
      ref.invalidate(workingHotelsProvider);
      if (mounted) {
        AppErrorPresenter.showSnackBar(context, 'Hotel profile updated.');
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
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const SrsSectionTitle('Hotel Profile'),
        const SizedBox(height: AppSpacing.sm),
        Form(
          key: _formKey,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.outlineSoft),
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _ProfileField(
                  label: 'Hotel Name',
                  child: AppTextFormField(
                    controller: _name,
                    labelText: 'Hotel Name',
                    prefixIcon: const Icon(Icons.apartment_rounded),
                    validator: _required,
                    inputFormatters: [LengthLimitingTextInputFormatter(150)],
                  ),
                ),
                _ProfileField(
                  label: 'Address',
                  child: AppTextFormField(
                    controller: _address,
                    labelText: 'Address',
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    maxLines: 2,
                    validator: _required,
                    inputFormatters: [LengthLimitingTextInputFormatter(255)],
                  ),
                ),
                _ProfileField(
                  label: 'City/Destination',
                  child: AppTextFormField(
                    controller: _city,
                    labelText: 'City/Destination',
                    prefixIcon: const Icon(Icons.location_city_outlined),
                    validator: _required,
                    inputFormatters: [LengthLimitingTextInputFormatter(100)],
                  ),
                ),
                _ProfileField(
                  label: 'Contact Phone',
                  child: AppTextFormField(
                    controller: _phone,
                    labelText: 'Contact Phone',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    validator: _phoneValidator,
                  ),
                ),
                _ProfileField(
                  label: 'Contact Email',
                  child: AppTextFormField(
                    controller: _email,
                    labelText: 'Contact Email',
                    prefixIcon: const Icon(Icons.email_outlined),
                    keyboardType: TextInputType.emailAddress,
                    validator: _emailValidator,
                    inputFormatters: [LengthLimitingTextInputFormatter(150)],
                  ),
                ),
                _ProfileField(
                  label: 'Description',
                  showDivider: false,
                  child: AppTextFormField(
                    controller: _description,
                    labelText: 'Description',
                    prefixIcon: const Icon(Icons.description_outlined),
                    maxLines: 3,
                    inputFormatters: [LengthLimitingTextInputFormatter(1000)],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        OwnerHotelContentCard(
          key: _contentKey,
          hotelId: widget.hotelId,
          showSaveButton: false,
        ),
        const SizedBox(height: AppSpacing.md),
        const SrsFieldLabel('Approval Status'),
        SrsPanel(
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.verified_user_outlined, size: 36),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _readableStatus(widget.hotel.approvalStatus),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          _approvalMessage(widget.hotel.approvalStatus),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  _StatusBadge(
                    label: _readableStatus(widget.hotel.publicationStatus),
                  ),
                ],
              ),
              const Divider(height: AppSpacing.xl),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _requiresRoomInspection,
                onChanged: _saving
                    ? null
                    : (value) =>
                        setState(() => _requiresRoomInspection = value),
                title: const Text('Require room inspection'),
                subtitle: const Text(
                  'Manager approval is required before serviced rooms return '
                  'to available inventory.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.label,
    required this.child,
    this.showDivider = true,
  });

  final String label;
  final Widget child;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: AppColors.outlineSoft))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 116,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 130),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.outline),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SrsPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(AppErrorPresenter.friendlyMessage(error)),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(onPressed: onRetry, child: const Text('Try Again')),
        ],
      ),
    );
  }
}

String? _required(String? value) {
  return value == null || value.trim().isEmpty
      ? 'This field is required.'
      : null;
}

String? _emailValidator(String? value) {
  return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value?.trim() ?? '')
      ? null
      : 'Enter a valid email address.';
}

String? _phoneValidator(String? value) {
  return RegExp(r'^\d{10}$').hasMatch(value?.trim() ?? '')
      ? null
      : 'Phone number must contain exactly 10 digits.';
}

String _readableStatus(String value) {
  if (value.trim().isEmpty) {
    return 'Not Available';
  }
  return value.replaceAllMapped(
    RegExp(r'(?<=[a-z])(?=[A-Z])'),
    (match) => ' ',
  );
}

String _approvalMessage(String status) {
  return switch (status) {
    'Approved' || 'Active' => 'Approved for marketplace publication.',
    'Rejected' => 'Review the rejection reason before resubmitting.',
    _ => 'Waiting for platform administrator review.',
  };
}
