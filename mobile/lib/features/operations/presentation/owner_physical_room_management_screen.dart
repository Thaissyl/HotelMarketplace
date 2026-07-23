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

class OwnerPhysicalRoomManagementScreen extends ConsumerStatefulWidget {
  const OwnerPhysicalRoomManagementScreen({
    super.key,
    required this.hotelId,
    this.initialRoomTypeId,
  });

  final String hotelId;
  final String? initialRoomTypeId;

  @override
  ConsumerState<OwnerPhysicalRoomManagementScreen> createState() =>
      _OwnerPhysicalRoomManagementScreenState();
}

class _OwnerPhysicalRoomManagementScreenState
    extends ConsumerState<OwnerPhysicalRoomManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _roomNumberController = TextEditingController();
  final _floorController = TextEditingController();
  final _notesController = TextEditingController();
  String? _roomTypeId;
  String _roomStatus = 'Available';
  String? _editingRoomId;
  String? _operationalStatus;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _roomTypeId = widget.initialRoomTypeId;
  }

  @override
  void dispose() {
    _roomNumberController.dispose();
    _floorController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _startEditing(RoomInventoryItem room) {
    final setupStatus = room.status == 'Available' || room.status == 'Inactive';
    setState(() {
      _editingRoomId = room.id;
      _roomTypeId = room.roomTypeId;
      _roomNumberController.text = room.roomNumber;
      _floorController.text = room.floor ?? '';
      _notesController.text = room.notes ?? '';
      _roomStatus = setupStatus ? room.status : room.status;
      _operationalStatus = setupStatus ? null : room.status;
    });
  }

  void _resetForm() {
    setState(() {
      _editingRoomId = null;
      _roomTypeId = widget.initialRoomTypeId;
      _roomNumberController.clear();
      _floorController.clear();
      _notesController.clear();
      _roomStatus = 'Available';
      _operationalStatus = null;
    });
  }

  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_formKey.currentState?.validate() != true) {
      return;
    }
    final roomTypeId = _roomTypeId;
    if (roomTypeId == null) {
      AppErrorPresenter.showSnackBar(context, 'Select a room type.');
      return;
    }

    setState(() => _saving = true);
    try {
      final editingId = _editingRoomId;
      if (editingId == null) {
        await ref.read(operationsApiProvider).createPhysicalRoom(
              hotelId: widget.hotelId,
              request: CreatePhysicalRoomRequest(
                roomTypeId: roomTypeId,
                roomNumber: _roomNumberController.text,
                initialStatus: _roomStatus,
                floor: _floorController.text,
                notes: _notesController.text,
              ),
            );
      } else {
        await ref.read(operationsApiProvider).updatePhysicalRoom(
              hotelId: widget.hotelId,
              physicalRoomId: editingId,
              request: UpdatePhysicalRoomRequest(
                roomNumber: _roomNumberController.text,
                status: _roomStatus,
                floor: _floorController.text,
                notes: _notesController.text,
              ),
            );
      }

      ref.invalidate(
        physicalRoomsProvider(PhysicalRoomsRequest(hotelId: widget.hotelId)),
      );
      _resetForm();
      if (mounted) {
        AppErrorPresenter.showSnackBar(
          context,
          editingId == null ? 'Physical room created.' : 'Room updated.',
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

  @override
  Widget build(BuildContext context) {
    final roomTypes = ref.watch(roomTypesProvider(widget.hotelId));
    final roomsRequest = PhysicalRoomsRequest(hotelId: widget.hotelId);
    final rooms = ref.watch(physicalRoomsProvider(roomsRequest));

    return SrsScreen(
      title: 'Physical Room Management Screen',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SrsSectionTitle('Physical Room List'),
          const SizedBox(height: AppSpacing.sm),
          roomTypes.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, stackTrace) => _ErrorPanel(
              error: error,
              onRetry: () => ref.invalidate(roomTypesProvider(widget.hotelId)),
            ),
            data: (roomTypeItems) => rooms.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, stackTrace) => _ErrorPanel(
                error: error,
                onRetry: () =>
                    ref.invalidate(physicalRoomsProvider(roomsRequest)),
              ),
              data: (roomItems) => _PhysicalRoomList(
                rooms: roomItems,
                roomTypes: roomTypeItems,
                onSelect: _startEditing,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextFormField(
                  controller: _roomNumberController,
                  labelText: 'Room Number',
                  hintText: 'Enter room number',
                  externalLabel: true,
                  prefixIcon: const Icon(Icons.meeting_room_outlined),
                  inputFormatters: [LengthLimitingTextInputFormatter(30)],
                  validator: (value) {
                    return (value?.trim().isEmpty ?? true)
                        ? 'Room number is required.'
                        : null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextFormField(
                  controller: _floorController,
                  labelText: 'Floor',
                  hintText: 'Enter floor number',
                  externalLabel: true,
                  prefixIcon: const Icon(Icons.stairs_outlined),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
                    LengthLimitingTextInputFormatter(4),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                const SrsFieldLabel('Room Type'),
                roomTypes.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (error, stackTrace) =>
                      const Text('Room types are unavailable.'),
                  data: (items) {
                    final safeValue =
                        items.any((item) => item.id == _roomTypeId)
                            ? _roomTypeId
                            : null;
                    return DropdownButtonFormField<String>(
                      initialValue: safeValue,
                      hint: const Text('Select room type'),
                      isExpanded: true,
                      items: [
                        for (final item in items)
                          DropdownMenuItem(
                            value: item.id,
                            child: Text(item.displayName),
                          ),
                      ],
                      onChanged: _editingRoomId == null
                          ? (value) => setState(() => _roomTypeId = value)
                          : null,
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                const SrsFieldLabel('Room Status'),
                DropdownButtonFormField<String>(
                  initialValue: _roomStatus,
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(
                      value: 'Available',
                      child: Text('Vacant / Available'),
                    ),
                    const DropdownMenuItem(
                      value: 'Inactive',
                      child: Text('Inactive'),
                    ),
                    if (_operationalStatus != null)
                      DropdownMenuItem(
                        value: _operationalStatus,
                        child: Text(_readableStatus(_operationalStatus!)),
                      ),
                  ],
                  onChanged: _operationalStatus != null || _saving
                      ? null
                      : (value) => setState(
                            () => _roomStatus = value ?? 'Available',
                          ),
                ),
                if (_operationalStatus != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'This room is controlled by an active operational '
                    'workflow. Finish that workflow before changing status.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                AppTextFormField(
                  controller: _notesController,
                  labelText: 'Notes',
                  hintText: 'Enter notes',
                  externalLabel: true,
                  maxLines: 3,
                  inputFormatters: [LengthLimitingTextInputFormatter(500)],
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _editingRoomId == null ? 'Save' : 'Save Changes',
                        ),
                ),
                if (_editingRoomId != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: _saving ? null : _resetForm,
                    child: const Text('Cancel Editing'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhysicalRoomList extends StatelessWidget {
  const _PhysicalRoomList({
    required this.rooms,
    required this.roomTypes,
    required this.onSelect,
  });

  final List<RoomInventoryItem> rooms;
  final List<RoomTypeInventoryItem> roomTypes;
  final ValueChanged<RoomInventoryItem> onSelect;

  @override
  Widget build(BuildContext context) {
    if (rooms.isEmpty) {
      return const SrsPanel(
        child: Text('No physical rooms have been created.'),
      );
    }

    final roomTypeNames = {
      for (final roomType in roomTypes) roomType.id: roomType.displayName,
    };
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.outlineSoft),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < rooms.length; index++) ...[
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              leading: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.meeting_room_outlined),
              ),
              title: Text(
                'Room ${rooms[index].roomNumber}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: Text(
                'Floor: ${_displayFloor(rooms[index].floor)}   |   '
                'Type: ${roomTypeNames[rooms[index].roomTypeId] ?? 'Room Type'}'
                '   |   Status: ${_readableStatus(rooms[index].status)}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => onSelect(rooms[index]),
            ),
            if (index < rooms.length - 1) const Divider(height: 1),
          ],
        ],
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

String _displayFloor(String? floor) {
  final value = floor?.trim() ?? '';
  return value.isEmpty ? '-' : value;
}

String _readableStatus(String status) {
  if (status == 'Available') {
    return 'Vacant';
  }
  if (status == 'Dirty' || status == 'Cleaning') {
    return 'Cleaning';
  }
  return status.replaceAllMapped(
    RegExp(r'(?<=[a-z])(?=[A-Z])'),
    (match) => ' ',
  );
}
