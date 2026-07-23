import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../shared/utils/app_formatters.dart';
import '../../../shared/widgets/app_error_presenter.dart';
import '../../../shared/widgets/app_text_form_field.dart';
import '../../../shared/widgets/srs_screen.dart';
import '../application/operations_providers.dart';
import '../domain/operations_models.dart';
import 'owner_physical_room_management_screen.dart';

class OwnerRoomTypeManagementScreen extends ConsumerStatefulWidget {
  const OwnerRoomTypeManagementScreen({super.key, required this.hotelId});

  final String hotelId;

  @override
  ConsumerState<OwnerRoomTypeManagementScreen> createState() =>
      _OwnerRoomTypeManagementScreenState();
}

class _OwnerRoomTypeManagementScreenState
    extends ConsumerState<OwnerRoomTypeManagementScreen> {
  static const _suggestedFacilities = <String>[
    'Wi-Fi',
    'Air Conditioning',
    'TV',
    'Mini Fridge',
    'Tea/Coffee Maker',
    'Safe',
    'Room Service',
    'Balcony',
    'Hair Dryer',
    'Toiletries',
  ];

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController(text: '100');
  final _descriptionController = TextEditingController();
  final Set<String> _facilities = <String>{};
  int _adultCapacity = 2;
  int _childCapacity = 1;
  String _status = 'Active';
  String? _editingRoomTypeId;
  String? _originalStatus;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _startEditing(RoomTypeInventoryItem item) {
    setState(() {
      _editingRoomTypeId = item.id;
      _originalStatus = item.status.isEmpty ? 'Active' : item.status;
      _nameController.text = item.name;
      _adultCapacity = item.adultCapacity;
      _childCapacity = item.childCapacity;
      _priceController.text = item.basePricePerNight.toStringAsFixed(0);
      _descriptionController.text = item.description ?? '';
      _facilities
        ..clear()
        ..addAll(_splitFacilities(item.facilities));
      _status = _originalStatus == 'Inactive' ? 'Inactive' : 'Active';
    });
  }

  void _resetForm() {
    setState(() {
      _editingRoomTypeId = null;
      _originalStatus = null;
      _nameController.clear();
      _priceController.text = '100';
      _descriptionController.clear();
      _adultCapacity = 2;
      _childCapacity = 1;
      _facilities.clear();
      _status = 'Active';
    });
  }

  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    final price = double.tryParse(_priceController.text.trim());
    if (price == null || price <= 0) {
      AppErrorPresenter.showSnackBar(
        context,
        'Base price must be greater than zero.',
      );
      return;
    }
    if (_originalStatus == 'Inactive' && _status == 'Active') {
      AppErrorPresenter.showSnackBar(
        context,
        'Inactive room types cannot be reactivated by the current API.',
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final request = UpdateRoomTypeRequest(
        name: _nameController.text,
        adultCapacity: _adultCapacity,
        childCapacity: _childCapacity,
        basePricePerNight: price,
        description: _descriptionController.text,
        facilities: _facilities.join(', '),
      );
      final editingId = _editingRoomTypeId;
      if (editingId == null) {
        await ref.read(operationsApiProvider).createRoomType(
              hotelId: widget.hotelId,
              request: CreateRoomTypeRequest(
                name: request.name,
                adultCapacity: request.adultCapacity,
                childCapacity: request.childCapacity,
                basePricePerNight: request.basePricePerNight,
                description: request.description,
                facilities: request.facilities,
              ),
            );
      } else {
        await ref.read(operationsApiProvider).updateRoomType(
              hotelId: widget.hotelId,
              roomTypeId: editingId,
              request: request,
            );
        if (_status == 'Inactive' && _originalStatus != 'Inactive') {
          await ref.read(operationsApiProvider).deactivateRoomType(
                hotelId: widget.hotelId,
                roomTypeId: editingId,
              );
        }
      }

      ref.invalidate(roomTypesProvider(widget.hotelId));
      _resetForm();
      if (mounted) {
        AppErrorPresenter.showSnackBar(
          context,
          editingId == null ? 'Room type created.' : 'Room type updated.',
        );
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

  Future<void> _deactivate(RoomTypeInventoryItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate room type?'),
        content: Text(
          '${item.displayName} will no longer be available for new bookings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await ref.read(operationsApiProvider).deactivateRoomType(
            hotelId: widget.hotelId,
            roomTypeId: item.id,
          );
      ref.invalidate(roomTypesProvider(widget.hotelId));
      if (mounted) {
        AppErrorPresenter.showSnackBar(context, 'Room type deactivated.');
      }
    } catch (error) {
      if (mounted) {
        await AppErrorPresenter.showBottomSheet(context, error);
      }
    }
  }

  Future<void> _addFacility() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add facility'),
        content: AppTextFormField(
          controller: controller,
          labelText: 'Facility name',
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
      setState(() => _facilities.add(value));
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomTypes = ref.watch(roomTypesProvider(widget.hotelId));

    return SrsScreen(
      title: 'Room Type Management Screen',
      actions: [
        IconButton(
          tooltip: 'Physical rooms',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) =>
                  OwnerPhysicalRoomManagementScreen(hotelId: widget.hotelId),
            ),
          ),
          icon: const Icon(Icons.meeting_room_outlined),
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SrsSectionTitle('Room Type List'),
            const SizedBox(height: AppSpacing.sm),
            roomTypes.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, stackTrace) => _ErrorPanel(
                error: error,
                onRetry: () =>
                    ref.invalidate(roomTypesProvider(widget.hotelId)),
              ),
              data: (items) => _RoomTypeList(
                items: items,
                onEdit: _startEditing,
                onDeactivate: _deactivate,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppTextFormField(
              controller: _nameController,
              labelText: 'Room Type Name',
              hintText: 'Enter room type name',
              externalLabel: true,
              inputFormatters: [LengthLimitingTextInputFormatter(100)],
              validator: (value) {
                return (value?.trim().length ?? 0) < 2
                    ? 'Enter at least 2 characters.'
                    : null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _NumberControl(
                    label: 'Capacity Adults',
                    value: _adultCapacity,
                    minimum: 1,
                    onChanged: (value) =>
                        setState(() => _adultCapacity = value),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _NumberControl(
                    label: 'Capacity Children',
                    value: _childCapacity,
                    minimum: 0,
                    onChanged: (value) =>
                        setState(() => _childCapacity = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextFormField(
              controller: _priceController,
              labelText: 'Base Price Per Night',
              hintText: '100',
              externalLabel: true,
              prefixIcon: const Icon(Icons.attach_money_rounded),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              validator: (value) {
                final amount = double.tryParse(value?.trim() ?? '');
                return amount == null || amount <= 0
                    ? 'Enter a price greater than zero.'
                    : null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextFormField(
              controller: _descriptionController,
              labelText: 'Description',
              hintText: 'Enter a short room description',
              externalLabel: true,
              maxLines: 2,
              inputFormatters: [LengthLimitingTextInputFormatter(500)],
            ),
            const SizedBox(height: AppSpacing.md),
            const SrsFieldLabel('Facilities'),
            SrsPanel(
              child: Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final facility in {
                    ..._suggestedFacilities,
                    ..._facilities,
                  })
                    FilterChip(
                      label: Text(facility),
                      selected: _facilities.contains(facility),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _facilities.add(facility);
                          } else {
                            _facilities.remove(facility);
                          }
                        });
                      },
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add'),
                    onPressed: _addFacility,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const SrsFieldLabel('Status'),
            DropdownButtonFormField<String>(
              initialValue: _status,
              items: const [
                DropdownMenuItem(value: 'Active', child: Text('Active')),
                DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _status = value ?? 'Active'),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_editingRoomTypeId == null ? 'Save' : 'Save Changes'),
            ),
            if (_editingRoomTypeId != null) ...[
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: _saving ? null : _resetForm,
                child: const Text('Cancel Editing'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RoomTypeList extends StatelessWidget {
  const _RoomTypeList({
    required this.items,
    required this.onEdit,
    required this.onDeactivate,
  });

  final List<RoomTypeInventoryItem> items;
  final ValueChanged<RoomTypeInventoryItem> onEdit;
  final ValueChanged<RoomTypeInventoryItem> onDeactivate;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SrsPanel(
        child: Text('No room types have been created.'),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.outlineSoft),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            _RoomTypeRow(
              item: items[index],
              onEdit: () => onEdit(items[index]),
              onDeactivate: () => onDeactivate(items[index]),
            ),
            if (index < items.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _RoomTypeRow extends StatelessWidget {
  const _RoomTypeRow({
    required this.item,
    required this.onEdit,
    required this.onDeactivate,
  });

  final RoomTypeInventoryItem item;
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;

  @override
  Widget build(BuildContext context) {
    final active = item.status.isEmpty || item.status == 'Active';
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: AppColors.surfaceSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.bed_rounded),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.displayName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Adults: ${item.adultCapacity}   '
                  'Children: ${item.childCapacity}   '
                  'Base Price: ${AppFormatters.money(item.basePricePerNight)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.outline),
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Text(active ? 'Active' : 'Inactive'),
          ),
          PopupMenuButton<String>(
            tooltip: 'Room type actions',
            onSelected: (value) {
              if (value == 'edit') {
                onEdit();
              } else {
                onDeactivate();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              if (active)
                const PopupMenuItem(
                  value: 'deactivate',
                  child: Text('Deactivate'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NumberControl extends StatelessWidget {
  const _NumberControl({
    required this.label,
    required this.value,
    required this.minimum,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int minimum;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SrsFieldLabel(label),
        Container(
          height: 56,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.outline),
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Text(value.toString()),
                ),
              ),
              IconButton(
                tooltip: 'Decrease $label',
                onPressed: value <= minimum ? null : () => onChanged(value - 1),
                icon: const Icon(Icons.remove_rounded),
              ),
              IconButton(
                tooltip: 'Increase $label',
                onPressed: () => onChanged(value + 1),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
        ),
      ],
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
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            onPressed: onRetry,
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}

List<String> _splitFacilities(String? value) {
  return (value ?? '')
      .split(RegExp(r'[,;\n]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}
