import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../shared/utils/app_formatters.dart';
import '../../../shared/widgets/app_error_presenter.dart';
import '../../../shared/widgets/app_text_form_field.dart';
import '../application/operations_providers.dart';
import '../domain/operations_models.dart';
import 'owner_hotel_content_card.dart';

class OwnerPropertyTab extends ConsumerWidget {
  const OwnerPropertyTab({super.key, required this.hotelId});

  final String hotelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hotel = ref.watch(ownerHotelProvider(hotelId));
    final roomTypes = ref.watch(roomTypesProvider(hotelId));
    final rooms = ref.watch(
      physicalRoomsProvider(PhysicalRoomsRequest(hotelId: hotelId)),
    );

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(ownerHotelProvider(hotelId));
        ref.invalidate(roomTypesProvider(hotelId));
        ref.invalidate(
          physicalRoomsProvider(PhysicalRoomsRequest(hotelId: hotelId)),
        );
      },
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text('Property setup', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Manage the hotel profile, room types, and physical room inventory used by marketplace search and operations.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          hotel.when(
            data: (item) => _HotelProfileCard(hotelId: hotelId, hotel: item),
            error: (error, stackTrace) => _ErrorCard(
              title: 'Unable to load hotel profile',
              error: error,
              onRetry: () => ref.invalidate(ownerHotelProvider(hotelId)),
            ),
            loading: () => const LinearProgressIndicator(),
          ),
          const SizedBox(height: AppSpacing.md),
          OwnerHotelContentCard(hotelId: hotelId),
          const SizedBox(height: AppSpacing.md),
          roomTypes.when(
            data: (items) => _RoomTypeSection(hotelId: hotelId, items: items),
            error: (error, stackTrace) => _ErrorCard(
              title: 'Unable to load room types',
              error: error,
              onRetry: () => ref.invalidate(roomTypesProvider(hotelId)),
            ),
            loading: () => const LinearProgressIndicator(),
          ),
          const SizedBox(height: AppSpacing.md),
          roomTypes.when(
            data: (roomTypeItems) => rooms.when(
              data: (roomItems) => _PhysicalRoomSection(
                hotelId: hotelId,
                roomTypes: roomTypeItems,
                rooms: roomItems,
              ),
              error: (error, stackTrace) => _ErrorCard(
                title: 'Unable to load physical rooms',
                error: error,
                onRetry: () => ref.invalidate(
                  physicalRoomsProvider(PhysicalRoomsRequest(hotelId: hotelId)),
                ),
              ),
              loading: () => const LinearProgressIndicator(),
            ),
            error: (error, stackTrace) => const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _HotelProfileCard extends ConsumerStatefulWidget {
  const _HotelProfileCard({
    required this.hotelId,
    required this.hotel,
  });

  final String hotelId;
  final WorkingHotel hotel;

  @override
  ConsumerState<_HotelProfileCard> createState() => _HotelProfileCardState();
}

class _HotelProfileCardState extends ConsumerState<_HotelProfileCard> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _city;
  late final TextEditingController _address;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _description;
  bool _saving = false;
  late bool _requiresRoomInspection;

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
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    setState(() => _saving = true);
    try {
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SectionHeader(
                icon: Icons.domain_rounded,
                title: 'Hotel profile',
                subtitle:
                    'This information is visible to guests after approval.',
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_user_outlined,
                      color: AppColors.brand,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Approval status',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          Text(
                            _readableHotelStatus(widget.hotel.approvalStatus),
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ],
                      ),
                    ),
                    _InventoryStatusPill(
                      label: _readableHotelStatus(
                        widget.hotel.publicationStatus,
                      ),
                      active: widget.hotel.publicationStatus.toLowerCase() ==
                              'published' ||
                          widget.hotel.publicationStatus.toLowerCase() ==
                              'active',
                    ),
                  ],
                ),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _requiresRoomInspection,
                onChanged: _saving
                    ? null
                    : (value) =>
                        setState(() => _requiresRoomInspection = value),
                title: const Text('Require room inspection'),
                subtitle: const Text(
                  'Cleaned and repaired rooms stay unavailable until a manager or owner releases them.',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
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
                labelText: 'Address',
                validator: _required,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextFormField(
                controller: _email,
                labelText: 'Contact email',
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  final text = value?.trim() ?? '';
                  return text.contains('@') ? null : 'Enter a valid email.';
                },
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextFormField(
                controller: _phone,
                labelText: 'Contact phone',
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: (value) {
                  final text = value?.trim() ?? '';
                  return RegExp(r'^\d{10}$').hasMatch(text)
                      ? null
                      : 'Phone number must contain 10 digits.';
                },
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextFormField(
                controller: _description,
                labelText: 'Description',
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
                label: const Text('Save hotel profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoomTypeSection extends ConsumerStatefulWidget {
  const _RoomTypeSection({
    required this.hotelId,
    required this.items,
  });

  final String hotelId;
  final List<RoomTypeInventoryItem> items;

  @override
  ConsumerState<_RoomTypeSection> createState() => _RoomTypeSectionState();
}

class _RoomTypeSectionState extends ConsumerState<_RoomTypeSection> {
  final _name = TextEditingController();
  final _adult = TextEditingController(text: '2');
  final _child = TextEditingController(text: '0');
  final _price = TextEditingController(text: '100');
  final _description = TextEditingController();
  final _facilities = TextEditingController();
  bool _creating = false;

  @override
  void dispose() {
    _name.dispose();
    _adult.dispose();
    _child.dispose();
    _price.dispose();
    _description.dispose();
    _facilities.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_name.text.trim().length < 2) {
      AppErrorPresenter.showSnackBar(context, 'Enter a room type name.');
      return;
    }

    final adultCapacity = int.tryParse(_adult.text) ?? 0;
    final childCapacity = int.tryParse(_child.text) ?? 0;
    final price = double.tryParse(_price.text) ?? 0;
    if (adultCapacity < 1 || childCapacity < 0 || price <= 0) {
      AppErrorPresenter.showSnackBar(
        context,
        'Capacity and price must be valid positive values.',
      );
      return;
    }

    setState(() => _creating = true);
    try {
      await ref.read(operationsApiProvider).createRoomType(
            hotelId: widget.hotelId,
            request: CreateRoomTypeRequest(
              name: _name.text,
              adultCapacity: adultCapacity,
              childCapacity: childCapacity,
              basePricePerNight: price,
              description: _description.text,
              facilities: _facilities.text,
            ),
          );
      _name.clear();
      _description.clear();
      _facilities.clear();
      ref.invalidate(roomTypesProvider(widget.hotelId));
      if (mounted) {
        AppErrorPresenter.showSnackBar(context, 'Room type created.');
      }
    } catch (error) {
      if (mounted) {
        await AppErrorPresenter.showBottomSheet(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _creating = false);
      }
    }
  }

  Future<void> _edit(RoomTypeInventoryItem item) async {
    final name = TextEditingController(text: item.name);
    final adults = TextEditingController(text: item.adultCapacity.toString());
    final children = TextEditingController(text: item.childCapacity.toString());
    final price = TextEditingController(
      text: item.basePricePerNight.toStringAsFixed(0),
    );
    final description = TextEditingController(text: item.description ?? '');
    final facilities = TextEditingController(text: item.facilities ?? '');
    final request = await showDialog<UpdateRoomTypeRequest>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit room type'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextFormField(controller: name, labelText: 'Name'),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: AppTextFormField(
                      controller: adults,
                      labelText: 'Adults',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppTextFormField(
                      controller: children,
                      labelText: 'Children',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextFormField(
                controller: price,
                labelText: 'Base price per night',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextFormField(
                controller: description,
                labelText: 'Description',
                maxLines: 2,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextFormField(
                controller: facilities,
                labelText: 'Facilities',
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final adultCapacity = int.tryParse(adults.text) ?? 0;
              final childCapacity = int.tryParse(children.text) ?? -1;
              final basePrice = double.tryParse(price.text) ?? -1;
              if (name.text.trim().length < 2 ||
                  adultCapacity < 1 ||
                  childCapacity < 0 ||
                  basePrice < 0) {
                AppErrorPresenter.showSnackBar(
                  context,
                  'Enter a valid name, capacity, and price.',
                );
                return;
              }
              Navigator.of(context).pop(
                UpdateRoomTypeRequest(
                  name: name.text,
                  adultCapacity: adultCapacity,
                  childCapacity: childCapacity,
                  basePricePerNight: basePrice,
                  description: description.text,
                  facilities: facilities.text,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    name.dispose();
    adults.dispose();
    children.dispose();
    price.dispose();
    description.dispose();
    facilities.dispose();
    if (request == null) {
      return;
    }
    try {
      await ref.read(operationsApiProvider).updateRoomType(
            hotelId: widget.hotelId,
            roomTypeId: item.id,
            request: request,
          );
      ref.invalidate(roomTypesProvider(widget.hotelId));
      if (mounted) {
        AppErrorPresenter.showSnackBar(context, 'Room type updated.');
      }
    } catch (error) {
      if (mounted) {
        await AppErrorPresenter.showBottomSheet(context, error);
      }
    }
  }

  Future<void> _deactivate(RoomTypeInventoryItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop selling this room type?'),
        content: Text(
          '${item.displayName} will no longer appear as active inventory. Existing future bookings prevent this action.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep active'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
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

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionHeader(
              icon: Icons.bed_rounded,
              title: 'Room types',
              subtitle: 'Define sellable categories such as Deluxe or Suite.',
            ),
            const SizedBox(height: AppSpacing.md),
            if (widget.items.isEmpty)
              const Text('No room types have been created yet.')
            else
              for (final item in widget.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _RoomTypeTile(
                    item: item,
                    onEdit: () => _edit(item),
                    onDeactivate: () => _deactivate(item),
                  ),
                ),
            const Divider(height: AppSpacing.xl),
            AppTextFormField(controller: _name, labelText: 'New room type'),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: AppTextFormField(
                    controller: _adult,
                    labelText: 'Adults',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppTextFormField(
                    controller: _child,
                    labelText: 'Children',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextFormField(
              controller: _price,
              labelText: 'Base price per night',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextFormField(
              controller: _description,
              labelText: 'Description',
              maxLines: 2,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextFormField(
              controller: _facilities,
              labelText: 'Facilities',
              hintText: 'Wi-Fi, workspace, minibar',
              maxLines: 2,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: _creating ? null : _create,
              icon: _creating
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_rounded),
              label: const Text('Create room type'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhysicalRoomSection extends ConsumerStatefulWidget {
  const _PhysicalRoomSection({
    required this.hotelId,
    required this.roomTypes,
    required this.rooms,
  });

  final String hotelId;
  final List<RoomTypeInventoryItem> roomTypes;
  final List<RoomInventoryItem> rooms;

  @override
  ConsumerState<_PhysicalRoomSection> createState() =>
      _PhysicalRoomSectionState();
}

class _PhysicalRoomSectionState extends ConsumerState<_PhysicalRoomSection> {
  final _roomNumber = TextEditingController();
  final _floor = TextEditingController();
  final _notes = TextEditingController();
  String? _roomTypeId;
  String _initialStatus = 'Available';
  bool _creating = false;

  @override
  void dispose() {
    _roomNumber.dispose();
    _floor.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final roomTypeId = _roomTypeId;
    if (roomTypeId == null || _roomNumber.text.trim().isEmpty) {
      AppErrorPresenter.showSnackBar(
        context,
        'Choose a room type and room number.',
      );
      return;
    }

    setState(() => _creating = true);
    try {
      await ref.read(operationsApiProvider).createPhysicalRoom(
            hotelId: widget.hotelId,
            request: CreatePhysicalRoomRequest(
              roomTypeId: roomTypeId,
              roomNumber: _roomNumber.text,
              initialStatus: _initialStatus,
              floor: _floor.text,
              notes: _notes.text,
            ),
          );
      _roomNumber.clear();
      _floor.clear();
      _notes.clear();
      ref.invalidate(
        physicalRoomsProvider(PhysicalRoomsRequest(hotelId: widget.hotelId)),
      );
      if (mounted) {
        AppErrorPresenter.showSnackBar(context, 'Physical room created.');
      }
    } catch (error) {
      if (mounted) {
        await AppErrorPresenter.showBottomSheet(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _creating = false);
      }
    }
  }

  Future<void> _editRoom(RoomInventoryItem room) async {
    final roomNumber = TextEditingController(text: room.roomNumber);
    final floor = TextEditingController(text: room.floor ?? '');
    final notes = TextEditingController(text: room.notes ?? '');
    var status = room.status == 'Inactive' ? 'Inactive' : 'Available';
    final request = await showDialog<UpdatePhysicalRoomRequest>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Edit room ${room.roomNumber}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextFormField(
                  controller: roomNumber,
                  labelText: 'Room number',
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextFormField(controller: floor, labelText: 'Floor'),
                const SizedBox(height: AppSpacing.sm),
                AppTextFormField(
                  controller: notes,
                  labelText: 'Operational notes',
                  maxLines: 3,
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Setup status'),
                  items: const [
                    DropdownMenuItem(
                      value: 'Available',
                      child: Text('Available'),
                    ),
                    DropdownMenuItem(
                      value: 'Inactive',
                      child: Text('Inactive'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => status = value);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (roomNumber.text.trim().isEmpty) {
                  AppErrorPresenter.showSnackBar(
                    context,
                    'Room number is required.',
                  );
                  return;
                }
                Navigator.of(context).pop(
                  UpdatePhysicalRoomRequest(
                    roomNumber: roomNumber.text,
                    status: status,
                    floor: floor.text,
                    notes: notes.text,
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    roomNumber.dispose();
    floor.dispose();
    notes.dispose();
    if (request == null) {
      return;
    }
    try {
      await ref.read(operationsApiProvider).updatePhysicalRoom(
            hotelId: widget.hotelId,
            physicalRoomId: room.id,
            request: request,
          );
      ref.invalidate(
        physicalRoomsProvider(PhysicalRoomsRequest(hotelId: widget.hotelId)),
      );
      if (mounted) {
        AppErrorPresenter.showSnackBar(context, 'Physical room updated.');
      }
    } catch (error) {
      if (mounted) {
        await AppErrorPresenter.showBottomSheet(context, error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final safeRoomTypeId =
        widget.roomTypes.any((item) => item.id == _roomTypeId)
            ? _roomTypeId
            : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionHeader(
              icon: Icons.meeting_room_rounded,
              title: 'Physical rooms',
              subtitle: 'Create actual room numbers mapped to a room type.',
            ),
            const SizedBox(height: AppSpacing.md),
            if (widget.rooms.isEmpty)
              const Text('No physical rooms have been created yet.')
            else
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.outline),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var index = 0;
                        index < widget.rooms.length;
                        index++) ...[
                      ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.meeting_room_outlined),
                        ),
                        title: Text('Room ${widget.rooms[index].roomNumber}'),
                        subtitle: Text(
                          'Floor ${widget.rooms[index].floor?.trim().isNotEmpty == true ? widget.rooms[index].floor : '-'}'
                          '  |  ${_roomTypeName(widget.rooms[index].roomTypeId)}'
                          '  |  ${_readableRoomStatus(widget.rooms[index].status)}',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _editRoom(widget.rooms[index]),
                      ),
                      if (index < widget.rooms.length - 1)
                        const Divider(height: 1),
                    ],
                  ],
                ),
              ),
            const Divider(height: AppSpacing.xl),
            DropdownButtonFormField<String>(
              initialValue: safeRoomTypeId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Room type'),
              items: [
                for (final item in widget.roomTypes)
                  DropdownMenuItem(
                    value: item.id,
                    child: Text(item.displayName),
                  ),
              ],
              onChanged: (value) => setState(() => _roomTypeId = value),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextFormField(
              controller: _roomNumber,
              labelText: 'Room number',
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextFormField(
              controller: _floor,
              labelText: 'Floor',
              inputFormatters: [LengthLimitingTextInputFormatter(20)],
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextFormField(
              controller: _notes,
              labelText: 'Operational notes',
              maxLines: 2,
              inputFormatters: [LengthLimitingTextInputFormatter(500)],
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _initialStatus,
              decoration: const InputDecoration(labelText: 'Initial status'),
              items: const [
                DropdownMenuItem(value: 'Available', child: Text('Available')),
                DropdownMenuItem(
                  value: 'Inactive',
                  child: Text('Inactive'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _initialStatus = value);
                }
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: _creating ? null : _create,
              icon: _creating
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_home_work_rounded),
              label: const Text('Create physical room'),
            ),
          ],
        ),
      ),
    );
  }

  String _roomTypeName(String roomTypeId) {
    return widget.roomTypes
            .where((item) => item.id == roomTypeId)
            .firstOrNull
            ?.displayName ??
        'Room type';
  }
}

class _RoomTypeTile extends StatelessWidget {
  const _RoomTypeTile({
    required this.item,
    required this.onEdit,
    required this.onDeactivate,
  });

  final RoomTypeInventoryItem item;
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        children: [
          const Icon(Icons.bed_rounded, color: AppColors.brand),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.displayName,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  'Adults: ${item.adultCapacity}  |  Children: ${item.childCapacity}'
                  '  |  ${AppFormatters.money(item.basePricePerNight)}',
                ),
                if ((item.facilities ?? '').isNotEmpty)
                  Text(
                    item.facilities!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          _InventoryStatusPill(
            label: item.status.isEmpty ? 'Active' : item.status,
            active: item.status.isEmpty || item.status == 'Active',
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
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'deactivate', child: Text('Deactivate')),
            ],
          ),
        ],
      ),
    );
  }
}

class _InventoryStatusPill extends StatelessWidget {
  const _InventoryStatusPill({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.brand.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          child: Icon(icon, color: AppColors.brand),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.title,
    required this.error,
    required this.onRetry,
  });

  final String title;
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(AppErrorPresenter.friendlyMessage(error)),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

String _readableHotelStatus(String value) {
  if (value.trim().isEmpty) {
    return 'Not available';
  }
  return value.replaceAllMapped(
    RegExp(r'(?<=[a-z])(?=[A-Z])'),
    (match) => ' ',
  );
}

String _readableRoomStatus(String value) {
  return value.replaceAllMapped(
    RegExp(r'(?<=[a-z])(?=[A-Z])'),
    (match) => ' ',
  );
}

String? _required(String? value) {
  return (value == null || value.trim().isEmpty)
      ? 'This field is required.'
      : null;
}
