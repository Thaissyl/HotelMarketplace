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
import '../application/selected_hotel_controller.dart';
import '../domain/operations_models.dart';

class OwnerHotelOnboarding extends ConsumerStatefulWidget {
  const OwnerHotelOnboarding({
    super.key,
    this.onRegistered,
  });

  final VoidCallback? onRegistered;

  @override
  ConsumerState<OwnerHotelOnboarding> createState() =>
      _OwnerHotelOnboardingState();
}

class _OwnerHotelOnboardingState extends ConsumerState<OwnerHotelOnboarding> {
  static const _availableAmenities = <String>[
    'Wi-Fi',
    'Parking',
    'Swimming Pool',
    'Restaurant',
    'Gym',
    'Spa',
    'Air Conditioning',
    'Room Service',
    'Laundry',
    'Bar',
    'Conference Room',
    'Airport Shuttle',
    'Pet Friendly',
  ];

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _city = TextEditingController();
  final _address = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _description = TextEditingController();
  final List<String> _imageUrls = <String>[];
  final Set<String> _amenities = <String>{};
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
    FocusManager.instance.primaryFocus?.unfocus();
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

      if (_imageUrls.isNotEmpty || _amenities.isNotEmpty) {
        await ref.read(operationsApiProvider).updateHotelContent(
              hotelId: hotel.id,
              request: UpdateHotelContentRequest(
                images: [
                  for (var index = 0; index < _imageUrls.length; index++)
                    HotelContentImage(
                      imageUrl: _imageUrls[index],
                      displayOrder: index,
                    ),
                ],
                amenities: [
                  for (final amenity in _amenities)
                    HotelContentAmenity(
                      code: _amenityCode(amenity),
                      name: amenity,
                      type: 'Hotel',
                    ),
                ],
                cancellationPolicy: const HotelCancellationPolicy(
                  name: 'Flexible',
                  freeCancellationHours: 24,
                  refundPercentage: 100,
                  description:
                      'Free cancellation is available until 24 hours before check-in.',
                ),
              ),
            );
      }

      ref.invalidate(workingHotelsProvider);
      if (mounted) {
        AppErrorPresenter.showSnackBar(
          context,
          'Hotel registered and submitted for platform review.',
        );
        widget.onRegistered?.call();
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

  Future<void> _addImageUrl() async {
    if (_imageUrls.length >= 5) {
      AppErrorPresenter.showSnackBar(
        context,
        'The registration mockup supports up to 5 preview images.',
      );
      return;
    }

    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Hotel Image'),
        content: AppTextFormField(
          controller: controller,
          labelText: 'Image URL',
          hintText: 'https://example.com/hotel.jpg',
          externalLabel: true,
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              final uri = Uri.tryParse(value);
              if (uri == null ||
                  !uri.hasScheme ||
                  (uri.scheme != 'http' && uri.scheme != 'https')) {
                AppErrorPresenter.showSnackBar(
                  context,
                  'Enter an absolute HTTP or HTTPS image URL.',
                );
                return;
              }
              Navigator.of(context).pop(value);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (url != null && mounted) {
      setState(() => _imageUrls.add(url));
    }
  }

  Future<void> _addAmenity() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Amenity'),
        content: AppTextFormField(
          controller: controller,
          labelText: 'Amenity Name',
          externalLabel: true,
          inputFormatters: [LengthLimitingTextInputFormatter(80)],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              Navigator.of(context).pop(text.isEmpty ? null : text);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null && mounted) {
      setState(() => _amenities.add(value));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextFormField(
                controller: _name,
                labelText: 'Hotel Name',
                hintText: 'Enter hotel name',
                externalLabel: true,
                inputFormatters: [LengthLimitingTextInputFormatter(150)],
                validator: _required,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextFormField(
                controller: _address,
                labelText: 'Address',
                hintText: 'Enter complete address',
                externalLabel: true,
                maxLines: 3,
                inputFormatters: [LengthLimitingTextInputFormatter(255)],
                validator: _required,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextFormField(
                controller: _city,
                labelText: 'City/Destination',
                hintText: 'Enter city or destination',
                externalLabel: true,
                inputFormatters: [LengthLimitingTextInputFormatter(100)],
                validator: _required,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextFormField(
                controller: _phone,
                labelText: 'Contact Phone',
                hintText: 'Enter contact phone number',
                externalLabel: true,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: _phoneValidator,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextFormField(
                controller: _email,
                labelText: 'Contact Email',
                hintText: 'Enter contact email address',
                externalLabel: true,
                keyboardType: TextInputType.emailAddress,
                inputFormatters: [LengthLimitingTextInputFormatter(150)],
                validator: _emailValidator,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextFormField(
                controller: _description,
                labelText: 'Description',
                hintText: 'Enter hotel description',
                externalLabel: true,
                maxLines: 4,
                inputFormatters: [LengthLimitingTextInputFormatter(1000)],
                validator: _required,
              ),
              const SizedBox(height: AppSpacing.md),
              const SrsFieldLabel('Images'),
              _RegistrationImagePicker(
                imageUrls: _imageUrls,
                onAdd: _addImageUrl,
                onRemove: (url) => setState(() => _imageUrls.remove(url)),
              ),
              const SizedBox(height: AppSpacing.md),
              const SrsFieldLabel('Amenities'),
              SrsPanel(
                child: Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final amenity in {
                      ..._availableAmenities,
                      ..._amenities,
                    })
                      FilterChip(
                        label: Text(amenity),
                        selected: _amenities.contains(amenity),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _amenities.add(amenity);
                            } else {
                              _amenities.remove(amenity);
                            }
                          });
                        },
                      ),
                    ActionChip(
                      avatar: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add More'),
                      onPressed: _addAmenity,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Register Hotel'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RegistrationImagePicker extends StatelessWidget {
  const _RegistrationImagePicker({
    required this.imageUrls,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> imageUrls;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onAdd,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.outline),
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        child: Column(
          children: [
            Row(
              children: [
                for (var index = 0; index < 5; index++) ...[
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: _ImageSlot(
                        url: index < imageUrls.length ? imageUrls[index] : null,
                        onRemove: index < imageUrls.length
                            ? () => onRemove(imageUrls[index])
                            : null,
                      ),
                    ),
                  ),
                  if (index < 4) const SizedBox(width: AppSpacing.xs),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_upload_outlined),
                SizedBox(width: AppSpacing.xs),
                Text('Tap to upload images'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageSlot extends StatelessWidget {
  const _ImageSlot({required this.url, required this.onRemove});

  final String? url;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft,
              border: Border.all(color: AppColors.outlineSoft),
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: url == null
                ? const Icon(Icons.image_outlined, color: AppColors.subtleInk)
                : Image.network(
                    url!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.broken_image_outlined),
                  ),
          ),
        ),
        if (onRemove != null)
          Positioned(
            right: -5,
            top: -5,
            child: IconButton.filled(
              visualDensity: VisualDensity.compact,
              iconSize: 14,
              tooltip: 'Remove image',
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded),
            ),
          ),
      ],
    );
  }
}

String? _required(String? value) {
  return value == null || value.trim().isEmpty
      ? 'This field is required.'
      : null;
}

String? _emailValidator(String? value) {
  final requiredError = _required(value);
  if (requiredError != null) {
    return requiredError;
  }
  return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value!.trim())
      ? null
      : 'Enter a valid email address.';
}

String? _phoneValidator(String? value) {
  return RegExp(r'^\d{10}$').hasMatch(value?.trim() ?? '')
      ? null
      : 'Phone number must contain exactly 10 digits.';
}

String _amenityCode(String name) {
  return name
      .trim()
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
}
