import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../shared/widgets/app_error_presenter.dart';
import '../../../shared/widgets/app_text_form_field.dart';
import '../application/operations_providers.dart';
import '../domain/operations_models.dart';

class OwnerHotelContentCard extends ConsumerWidget {
  const OwnerHotelContentCard({super.key, required this.hotelId});
  final String hotelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(hotelContentProvider(hotelId));
    return content.when(
      data: (value) => _ContentEditor(hotelId: hotelId, content: value),
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: LinearProgressIndicator(),
        ),
      ),
      error: (error, stackTrace) => Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              const Text('Unable to load marketplace content.'),
              const SizedBox(height: AppSpacing.sm),
              Text(AppErrorPresenter.friendlyMessage(error)),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(hotelContentProvider(hotelId)),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContentEditor extends ConsumerStatefulWidget {
  const _ContentEditor({required this.hotelId, required this.content});
  final String hotelId;
  final HotelContent content;

  @override
  ConsumerState<_ContentEditor> createState() => _ContentEditorState();
}

class _ContentEditorState extends ConsumerState<_ContentEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _images;
  late final TextEditingController _amenities;
  late final TextEditingController _policyName;
  late final TextEditingController _freeHours;
  late final TextEditingController _refundPercentage;
  late final TextEditingController _policyDescription;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _images = TextEditingController(
      text: widget.content.images.map((item) => item.imageUrl).join('\n'),
    );
    _amenities = TextEditingController(
      text: widget.content.amenities
          .map((item) => '${item.code} | ${item.name} | ${item.type}')
          .join('\n'),
    );
    final policy = widget.content.cancellationPolicy;
    _policyName = TextEditingController(text: policy?.name ?? 'Flexible');
    _freeHours = TextEditingController(
      text: (policy?.freeCancellationHours ?? 24).toString(),
    );
    _refundPercentage = TextEditingController(
      text: (policy?.refundPercentage ?? 100).toStringAsFixed(0),
    );
    _policyDescription = TextEditingController(text: policy?.description ?? '');
  }

  @override
  void dispose() {
    _images.dispose();
    _amenities.dispose();
    _policyName.dispose();
    _freeHours.dispose();
    _refundPercentage.dispose();
    _policyDescription.dispose();
    super.dispose();
  }

  List<String> _nonEmptyLines(String value) => value
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);

  String? _validateImages(String? value) {
    final lines = _nonEmptyLines(value ?? '');
    if (lines.length > 20) {
      return 'Use at most 20 image URLs.';
    }
    final invalid = lines.any((line) {
      final uri = Uri.tryParse(line);
      return uri == null ||
          !uri.hasScheme ||
          (uri.scheme != 'http' && uri.scheme != 'https');
    });
    return invalid ? 'Each line must be an absolute HTTP or HTTPS URL.' : null;
  }

  String? _validateAmenities(String? value) {
    final lines = _nonEmptyLines(value ?? '');
    if (lines.length > 50) {
      return 'Use at most 50 amenities.';
    }
    return lines.any((line) => line.split('|').length != 3)
        ? 'Use one amenity per line: code | name | type.'
        : null;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState?.validate() != true) {
      return;
    }
    final images = _nonEmptyLines(_images.text)
        .asMap()
        .entries
        .map(
          (entry) => HotelContentImage(
            imageUrl: entry.value,
            displayOrder: entry.key,
          ),
        )
        .toList(growable: false);
    final amenities = _nonEmptyLines(_amenities.text).map((line) {
      final parts = line.split('|').map((part) => part.trim()).toList();
      return HotelContentAmenity(
        code: parts[0],
        name: parts[1],
        type: parts[2],
      );
    }).toList(growable: false);

    setState(() => _saving = true);
    try {
      await ref.read(operationsApiProvider).updateHotelContent(
            hotelId: widget.hotelId,
            request: UpdateHotelContentRequest(
              images: images,
              amenities: amenities,
              cancellationPolicy: HotelCancellationPolicy(
                name: _policyName.text,
                freeCancellationHours: int.parse(_freeHours.text),
                refundPercentage: double.parse(_refundPercentage.text),
                description: _policyDescription.text,
              ),
            ),
          );
      ref.invalidate(hotelContentProvider(widget.hotelId));
      if (mounted) {
        AppErrorPresenter.showSnackBar(context, 'Marketplace content updated.');
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

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required.' : null;

  String? _range(String? value, int minimum, int maximum) {
    final number = int.tryParse(value ?? '');
    return number == null || number < minimum || number > maximum
        ? 'Enter a value from $minimum to $maximum.'
        : null;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Marketplace content',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Manage guest-facing photos, amenities, and cancellation terms.',
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextFormField(
                controller: _images,
                labelText: 'Image URLs (one per line)',
                maxLines: 4,
                validator: _validateImages,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextFormField(
                controller: _amenities,
                labelText: 'Amenities: code | name | type',
                maxLines: 4,
                validator: _validateAmenities,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextFormField(
                controller: _policyName,
                labelText: 'Cancellation policy name',
                validator: _required,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: AppTextFormField(
                      controller: _freeHours,
                      labelText: 'Free cancellation hours',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (value) => _range(value, 0, 8760),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppTextFormField(
                      controller: _refundPercentage,
                      labelText: 'Refund %',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (value) => _range(value, 0, 100),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextFormField(
                controller: _policyDescription,
                labelText: 'Policy description',
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(_saving ? 'Saving' : 'Save marketplace content'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
