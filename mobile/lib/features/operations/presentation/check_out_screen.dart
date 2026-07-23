import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../shared/utils/app_formatters.dart';
import '../../../shared/widgets/app_error_presenter.dart';
import '../application/operations_providers.dart';
import '../domain/operations_models.dart';
import 'front_desk_components.dart';

class CheckOutScreen extends ConsumerStatefulWidget {
  const CheckOutScreen({
    super.key,
    required this.hotelId,
    required this.booking,
  });

  final String hotelId;
  final FrontDeskBookingSummary booking;

  @override
  ConsumerState<CheckOutScreen> createState() => _CheckOutScreenState();
}

class _CheckOutScreenState extends ConsumerState<CheckOutScreen> {
  PaymentCollectionSummary? _summary;
  Object? _summaryError;
  bool _loadingSummary = false;
  bool _recordingPayment = false;
  bool _checkingOut = false;

  bool get _isPayAtProperty => widget.booking.paymentMode == 'PayAtProperty';

  double get _expectedAmount =>
      _summary?.expectedAmount ?? widget.booking.totalAmount;

  double get _collectedAmount {
    if (!_isPayAtProperty) {
      return widget.booking.totalAmount;
    }
    return _summary?.collectedAmount ?? 0;
  }

  double get _remainingBalance {
    if (!_isPayAtProperty) {
      return 0;
    }
    return _summary?.remainingBalance ?? widget.booking.totalAmount;
  }

  @override
  void initState() {
    super.initState();
    if (_isPayAtProperty) {
      Future<void>.microtask(_loadPaymentSummary);
    }
  }

  Future<void> _loadPaymentSummary() async {
    setState(() {
      _loadingSummary = true;
      _summaryError = null;
    });
    try {
      final summary =
          await ref.read(operationsApiProvider).getPaymentCollections(
                hotelId: widget.hotelId,
                bookingId: widget.booking.bookingId,
              );
      if (mounted) {
        setState(() => _summary = summary);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _summaryError = error);
      }
    } finally {
      if (mounted) {
        setState(() => _loadingSummary = false);
      }
    }
  }

  Future<void> _recordPayment() async {
    final request = await showDialog<_PaymentEntry>(
      context: context,
      builder: (context) => _RecordPaymentDialog(
        bookingCode: widget.booking.bookingCode,
        maximumAmount: _remainingBalance,
      ),
    );
    if (request == null || !mounted) {
      return;
    }

    setState(() => _recordingPayment = true);
    try {
      final summary =
          await ref.read(operationsApiProvider).recordPaymentCollection(
                hotelId: widget.hotelId,
                bookingId: widget.booking.bookingId,
                amount: request.amount,
                method: request.method,
                collectedAtUtc: DateTime.now().toUtc(),
                reference: request.reference,
                note: request.note,
              );
      if (mounted) {
        setState(() {
          _summary = summary;
          _summaryError = null;
        });
        AppErrorPresenter.showSnackBar(context, 'Payment record saved.');
      }
    } catch (error) {
      if (mounted) {
        await AppErrorPresenter.showBottomSheet(
          context,
          error,
          title: 'Payment not recorded',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _recordingPayment = false);
      }
    }
  }

  Future<void> _confirmCheckout() async {
    if (_isPayAtProperty && _remainingBalance > 0.009) {
      AppErrorPresenter.showSnackBar(
        context,
        'Record the outstanding balance before checkout.',
      );
      return;
    }

    setState(() => _checkingOut = true);
    try {
      final result = await ref.read(operationsApiProvider).checkOut(
            hotelId: widget.hotelId,
            bookingId: widget.booking.bookingId,
            confirmPayAtPropertyCollection: _isPayAtProperty,
            cashCollectedAmount: 0,
            collectionMethod: 'Cash',
            collectionReference: '',
            collectionNote: '',
          );
      if (mounted) {
        Navigator.of(context).pop(result);
      }
    } catch (error) {
      if (mounted) {
        await AppErrorPresenter.showBottomSheet(
          context,
          error,
          title: 'Checkout not completed',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _checkingOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FrontDeskRouteScaffold(
      title: 'Check-out / Payment Collection',
      body: RefreshIndicator(
        onRefresh: _isPayAtProperty ? _loadPaymentSummary : () async {},
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _StaySummary(booking: widget.booking),
            const SizedBox(height: AppSpacing.sm),
            FrontDeskPanel(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Room Charge Amount',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Text(
                    AppFormatters.money(_expectedAmount),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _CollectionRecords(
              records: _summary?.collections ?? const [],
              loading: _loadingSummary,
              error: _summaryError,
              isPayAtProperty: _isPayAtProperty,
              onRetry: _loadPaymentSummary,
            ),
            const SizedBox(height: AppSpacing.sm),
            FrontDeskPanel(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Outstanding Balance',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Text(
                    AppFormatters.money(_remainingBalance),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _ReceiptPreview(
              booking: widget.booking,
              expectedAmount: _expectedAmount,
              collectedAmount: _collectedAmount,
              remainingBalance: _remainingBalance,
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: !_isPayAtProperty ||
                        _remainingBalance <= 0.009 ||
                        _recordingPayment ||
                        _loadingSummary ||
                        _summaryError != null
                    ? null
                    : _recordPayment,
                icon: _recordingPayment
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_card_outlined),
                label: const Text('Record Payment Button'),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _checkingOut ||
                        _loadingSummary ||
                        _summaryError != null ||
                        (_isPayAtProperty && _remainingBalance > 0.009)
                    ? null
                    : _confirmCheckout,
                icon: _checkingOut
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: const Text('Confirm Checkout Button'),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

class _StaySummary extends StatelessWidget {
  const _StaySummary({required this.booking});

  final FrontDeskBookingSummary booking;

  @override
  Widget build(BuildContext context) {
    final roomType = booking.roomTypeName.isEmpty
        ? 'Room type unavailable'
        : booking.roomTypeName;
    final assignedRoom = booking.assignedRooms.isEmpty
        ? roomType
        : '$roomType (${booking.displayAssignedRooms})';

    return FrontDeskPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FrontDeskSectionTitle('Stay Summary'),
          const SizedBox(height: AppSpacing.md),
          FrontDeskInfoRow(
            icon: Icons.confirmation_number_outlined,
            label: 'Booking Code',
            value: booking.bookingCode,
          ),
          FrontDeskInfoRow(
            icon: Icons.person_outline,
            label: 'Guest',
            value: booking.guestFullName,
          ),
          FrontDeskInfoRow(
            icon: Icons.bed_outlined,
            label: 'Assigned Room',
            value: assignedRoom,
          ),
          FrontDeskInfoRow(
            icon: Icons.calendar_month_outlined,
            label: 'Stay Dates',
            value: booking.displayStayDates,
          ),
        ],
      ),
    );
  }
}

class _CollectionRecords extends StatelessWidget {
  const _CollectionRecords({
    required this.records,
    required this.loading,
    required this.error,
    required this.isPayAtProperty,
    required this.onRetry,
  });

  final List<PaymentCollectionRecord> records;
  final bool loading;
  final Object? error;
  final bool isPayAtProperty;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return FrontDeskPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FrontDeskSectionTitle('Collection Records'),
          const SizedBox(height: AppSpacing.md),
          if (!isPayAtProperty)
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.verified_outlined),
              title: Text('Demo platform payment confirmed'),
              subtitle: Text(
                'No pay-at-property collection is required.',
              ),
            )
          else if (loading)
            const LinearProgressIndicator()
          else if (error != null)
            Row(
              children: [
                const Expanded(
                  child: Text('Unable to load collection records.'),
                ),
                TextButton(onPressed: onRetry, child: const Text('Try Again')),
              ],
            )
          else if (records.isEmpty)
            const Text('No payment has been recorded at the property.')
          else
            for (var index = 0; index < records.length; index++) ...[
              if (index > 0) const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    const Icon(Icons.credit_card_outlined),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppFormatters.displayDateTime(
                              records[index].collectedAtUtc.toLocal(),
                            ),
                          ),
                          Text(records[index].methodLabel),
                        ],
                      ),
                    ),
                    Text(
                      AppFormatters.money(records[index].amount),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }
}

class _ReceiptPreview extends StatelessWidget {
  const _ReceiptPreview({
    required this.booking,
    required this.expectedAmount,
    required this.collectedAmount,
    required this.remainingBalance,
  });

  final FrontDeskBookingSummary booking;
  final double expectedAmount;
  final double collectedAmount;
  final double remainingBalance;

  @override
  Widget build(BuildContext context) {
    return FrontDeskPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FrontDeskSectionTitle('Customer Receipt Preview'),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
                style: BorderStyle.solid,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                const _ReceiptRow(label: 'Item', value: 'Amount'),
                const SizedBox(height: AppSpacing.sm),
                _ReceiptRow(
                  label:
                      'Room Charge (${booking.nights} Night${booking.nights == 1 ? '' : 's'})',
                  value: AppFormatters.money(expectedAmount),
                ),
                _ReceiptRow(
                  label: 'Payments',
                  value: '-${AppFormatters.money(collectedAmount)}',
                ),
                const Divider(),
                _ReceiptRow(
                  label: 'Balance Due',
                  value: AppFormatters.money(remainingBalance),
                  emphasized: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final style = emphasized
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _RecordPaymentDialog extends StatefulWidget {
  const _RecordPaymentDialog({
    required this.bookingCode,
    required this.maximumAmount,
  });

  final String bookingCode;
  final double maximumAmount;

  @override
  State<_RecordPaymentDialog> createState() => _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends State<_RecordPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final TextEditingController _reference;
  final _note = TextEditingController();
  String _method = 'Cash';

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(
      text: widget.maximumAmount.toStringAsFixed(2),
    );
    _reference = TextEditingController(
      text: 'FD-${widget.bookingCode}-${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    Navigator.of(context).pop(
      _PaymentEntry(
        amount: double.parse(_amount.text),
        method: _method,
        reference: _reference.text.trim(),
        note: _note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Record Payment'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                decoration: const InputDecoration(labelText: 'Amount'),
                validator: (value) {
                  final amount = double.tryParse(value ?? '');
                  if (amount == null || amount <= 0) {
                    return 'Enter an amount greater than zero.';
                  }
                  if (amount > widget.maximumAmount + 0.009) {
                    return 'Amount cannot exceed the outstanding balance.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: _method,
                decoration: const InputDecoration(labelText: 'Method'),
                items: const [
                  DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'Card', child: Text('Card')),
                  DropdownMenuItem(
                    value: 'BankTransfer',
                    child: Text('Bank Transfer'),
                  ),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _method = value);
                  }
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _reference,
                decoration: const InputDecoration(labelText: 'Reference'),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty || text.length > 128) {
                    return 'Enter a unique payment reference.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _note,
                maxLength: 500,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Note (Optional)',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save Payment')),
      ],
    );
  }
}

class _PaymentEntry {
  const _PaymentEntry({
    required this.amount,
    required this.method,
    required this.reference,
    required this.note,
  });

  final double amount;
  final String method;
  final String reference;
  final String note;
}
