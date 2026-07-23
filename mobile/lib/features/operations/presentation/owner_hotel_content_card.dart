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

class OwnerHotelContentCard extends ConsumerStatefulWidget {
  const OwnerHotelContentCard({
    super.key,
    required this.hotelId,
    this.showSaveButton = true,
  });

  final String hotelId;
  final bool showSaveButton;

  @override
  ConsumerState<OwnerHotelContentCard> createState() =>
      OwnerHotelContentCardState();
}

class OwnerHotelContentCardState extends ConsumerState<OwnerHotelContentCard> {
  static const _suggestedAmenities = <String>[
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

  final _policyDescription = TextEditingController();
  final List<String> _imageUrls = <String>[];
  final Set<String> _amenities = <String>{};
  bool _initialized = false;
  bool _saving = false;
  String _policyName = 'Flexible';
  int _freeCancellationHours = 24;
  double _refundPercentage = 100;

  @override
  void didUpdateWidget(covariant OwnerHotelContentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hotelId != widget.hotelId) {
      _initialized = false;
      _imageUrls.clear();
      _amenities.clear();
      _policyDescription.clear();
    }
  }

  @override
  void dispose() {
    _policyDescription.dispose();
    super.dispose();
  }

  void _initialize(HotelContent content) {
    if (_initialized) {
      return;
    }
    _initialized = true;
    final orderedImages = [...content.images]
      ..sort((left, right) => left.displayOrder.compareTo(right.displayOrder));
    _imageUrls
      ..clear()
      ..addAll(orderedImages.map((image) => image.imageUrl));
    _amenities
      ..clear()
      ..addAll(content.amenities.map((amenity) => amenity.name));
    final policy = content.cancellationPolicy;
    _policyName =
        policy?.name.trim().isNotEmpty == true ? policy!.name : 'Flexible';
    _freeCancellationHours = policy?.freeCancellationHours ?? 24;
    _refundPercentage = policy?.refundPercentage ?? 100;
    _policyDescription.text = policy?.description ?? '';
  }

  Future<bool> saveContent({bool showFeedback = true}) async {
    if (!_initialized) {
      if (mounted) {
        AppErrorPresenter.showSnackBar(
          context,
          'Hotel content is still loading.',
        );
      }
      return false;
    }

    setState(() => _saving = true);
    try {
      await ref.read(operationsApiProvider).updateHotelContent(
            hotelId: widget.hotelId,
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
              cancellationPolicy: HotelCancellationPolicy(
                name: _policyName,
                freeCancellationHours: _freeCancellationHours,
                refundPercentage: _refundPercentage,
                description: _policyDescription.text,
              ),
            ),
          );
      ref.invalidate(hotelContentProvider(widget.hotelId));
      if (showFeedback && mounted) {
        AppErrorPresenter.showSnackBar(context, 'Hotel content updated.');
      }
      return true;
    } catch (error) {
      if (mounted) {
        await AppErrorPresenter.showBottomSheet(context, error);
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _addImageUrl() async {
    if (_imageUrls.length >= 20) {
      AppErrorPresenter.showSnackBar(
        context,
        'A hotel can contain at most 20 images.',
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
    final amenity = await showDialog<String>(
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
              final value = controller.text.trim();
              Navigator.of(context).pop(value.isEmpty ? null : value);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (amenity != null && mounted) {
      setState(() => _amenities.add(amenity));
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = ref.watch(hotelContentProvider(widget.hotelId));
    return content.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: LinearProgressIndicator(),
      ),
      error: (error, stackTrace) => SrsPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(AppErrorPresenter.friendlyMessage(error)),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: () =>
                  ref.invalidate(hotelContentProvider(widget.hotelId)),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
      data: (value) {
        _initialize(value);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SrsFieldLabel('Images'),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.outline),
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 92,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _imageUrls.length + 1,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        if (index == _imageUrls.length) {
                          return _AddImageButton(onPressed: _addImageUrl);
                        }
                        final url = _imageUrls[index];
                        return _EditableImage(
                          url: url,
                          onRemove: () =>
                              setState(() => _imageUrls.removeAt(index)),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const SrsFieldLabel('Amenities'),
            SrsPanel(
              child: Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final amenity in {
                    ..._suggestedAmenities,
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
                    label: const Text('Add'),
                    onPressed: _addAmenity,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextFormField(
              controller: _policyDescription,
              labelText: 'Cancellation Policy',
              hintText: 'Describe cancellation and refund conditions',
              externalLabel: true,
              maxLines: 4,
              inputFormatters: [LengthLimitingTextInputFormatter(1000)],
            ),
            if (widget.showSaveButton) ...[
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: _saving ? null : saveContent,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _EditableImage extends StatelessWidget {
  const _EditableImage({required this.url, required this.onRemove});

  final String url;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              child: Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: AppColors.surfaceSoft,
                  child: const Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
          ),
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
      ),
    );
  }
}

class _AddImageButton extends StatelessWidget {
  const _AddImageButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      child: OutlinedButton(
        onPressed: onPressed,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

String _amenityCode(String name) {
  return name
      .trim()
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
}
