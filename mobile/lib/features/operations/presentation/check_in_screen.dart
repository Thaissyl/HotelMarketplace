import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../shared/widgets/app_error_presenter.dart';
import '../application/operations_providers.dart';
import '../domain/operations_models.dart';
import 'front_desk_components.dart';

class CheckInScreen extends ConsumerStatefulWidget {
  const CheckInScreen({
    super.key,
    required this.hotelId,
    required this.booking,
    required this.physicalRoomIds,
    required this.roomNumbers,
  });

  final String hotelId;
  final FrontDeskBookingSummary booking;
  final List<String> physicalRoomIds;
  final List<String> roomNumbers;

  @override
  ConsumerState<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends ConsumerState<CheckInScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _holderName;
  final _identityNumber = TextEditingController();
  String _identityType = 'Passport';
  bool _arrivalConfirmed = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _holderName = TextEditingController(text: widget.booking.guestFullName);
  }

  @override
  void dispose() {
    _holderName.dispose();
    _identityNumber.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (!_arrivalConfirmed) {
      AppErrorPresenter.showSnackBar(
        context,
        'Confirm that the guest has arrived and the identity was verified.',
      );
      return;
    }
    if (widget.physicalRoomIds.length != widget.booking.roomQuantity) {
      AppErrorPresenter.showSnackBar(
        context,
        'The booking must have exactly ${widget.booking.roomQuantity} assigned room(s).',
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final result = await ref.read(operationsApiProvider).checkIn(
            hotelId: widget.hotelId,
            bookingId: widget.booking.bookingId,
            physicalRoomIds: widget.physicalRoomIds,
            guestFullName: _holderName.text,
            identityDocumentType: _identityType,
            identityDocumentNumber: _identityNumber.text,
          );
      if (mounted) {
        Navigator.of(context).pop(result);
      }
    } catch (error) {
      if (mounted) {
        await AppErrorPresenter.showBottomSheet(
          context,
          error,
          title: 'Check-in not completed',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FrontDeskRouteScaffold(
      title: 'Check-in Screen',
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            FrontDeskPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FrontDeskSectionTitle('Booking Code'),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    initialValue: widget.booking.bookingCode,
                    readOnly: true,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.confirmation_number_outlined),
                      suffixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text('Read-only booking code.'),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FrontDeskPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FrontDeskSectionTitle('Guest Identity'),
                  const SizedBox(height: AppSpacing.lg),
                  const FrontDeskFieldLabel('Guest Identity Type'),
                  DropdownButtonFormField<String>(
                    initialValue: _identityType,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Passport',
                        child: Text('Passport'),
                      ),
                      DropdownMenuItem(
                        value: 'NationalId',
                        child: Text('National ID'),
                      ),
                      DropdownMenuItem(
                        value: 'DriverLicense',
                        child: Text('Driver License'),
                      ),
                    ],
                    onChanged: _submitting
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _identityType = value);
                            }
                          },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const FrontDeskFieldLabel('Guest Identity Number'),
                  TextFormField(
                    controller: _identityNumber,
                    enabled: !_submitting,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.credit_card_outlined),
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.length < 3 || text.length > 64) {
                        return 'Enter a valid identity document number.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const FrontDeskFieldLabel('Identity Holder Name'),
                  TextFormField(
                    controller: _holderName,
                    enabled: !_submitting,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.length < 2 || text.length > 200) {
                        return 'Enter the identity holder full name.';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FrontDeskPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FrontDeskSectionTitle('Assigned Physical Room'),
                  const SizedBox(height: AppSpacing.md),
                  const FrontDeskFieldLabel('Assigned Physical Room'),
                  TextFormField(
                    initialValue: widget.roomNumbers.join(', '),
                    readOnly: true,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.meeting_room_outlined),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text('Room assigned to this booking.'),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FrontDeskPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FrontDeskSectionTitle('Arrival Confirmation'),
                  const SizedBox(height: AppSpacing.sm),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _arrivalConfirmed,
                    onChanged: _submitting
                        ? null
                        : (value) => setState(
                              () => _arrivalConfirmed = value ?? false,
                            ),
                    title: const Text(
                      'I confirm the guest has arrived and identity has been verified.',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Check-in Button'),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}
