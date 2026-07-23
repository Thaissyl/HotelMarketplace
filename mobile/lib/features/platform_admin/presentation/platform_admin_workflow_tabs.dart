import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../shared/utils/app_formatters.dart';
import '../../../shared/widgets/app_error_presenter.dart';
import '../../../shared/widgets/app_shimmer.dart';
import '../application/platform_admin_providers.dart';
import '../domain/platform_admin_models.dart';

final actionableAdminRefundsProvider =
    FutureProvider.autoDispose<List<AdminRefund>>((ref) async {
  final api = ref.watch(platformAdminApiProvider);
  final groups = await Future.wait([
    api.getRefunds(status: 'PendingReview'),
    api.getRefunds(status: 'Approved'),
  ]);
  final refunds = [...groups[0], ...groups[1]]
    ..sort((left, right) => left.createdAtUtc.compareTo(right.createdAtUtc));
  return refunds;
});

class AdminOverviewTab extends ConsumerStatefulWidget {
  const AdminOverviewTab({super.key});

  @override
  ConsumerState<AdminOverviewTab> createState() => _AdminOverviewTabState();
}

class _AdminOverviewTabState extends ConsumerState<AdminOverviewTab> {
  String? _hotelId;

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(adminFinanceSummaryProvider);
    return _AdminRefreshView(
      onRefresh: () async => ref.invalidate(adminFinanceSummaryProvider),
      child: summary.when(
        loading: () => const _LoadingBody(),
        error: (error, _) => _ErrorBody(
          title: 'Unable to load dashboard',
          error: error,
          onRetry: () => ref.invalidate(adminFinanceSummaryProvider),
        ),
        data: (items) {
          final selected = _hotelId == null
              ? items
              : items.where((item) => item.hotelId == _hotelId).toList();
          final gross = selected.fold<double>(
            0,
            (sum, item) => sum + item.grossBookingRevenue,
          );
          final commission = selected.fold<double>(
            0,
            (sum, item) => sum + item.platformCommission,
          );
          final payable = selected.fold<double>(
            0,
            (sum, item) => sum + item.hotelNetReceivable,
          );
          final bookings = selected.fold<int>(
            0,
            (sum, item) => sum + item.successfulBookingCount,
          );

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              const _ScreenHeading(
                title: 'Admin Dashboard',
                subtitle: 'Platform booking and financial performance',
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: _ReadOnlyFilter(
                      label: 'Date range',
                      value: 'All recorded dates',
                      icon: Icons.calendar_today_outlined,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      initialValue: _hotelId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Hotel',
                        prefixIcon: Icon(Icons.apartment_outlined),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All hotels'),
                        ),
                        for (final item in items)
                          DropdownMenuItem(
                            value: item.hotelId,
                            child: Text(
                              _hotelName(item.hotelName),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) => setState(() => _hotelId = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _MetricGrid(
                metrics: [
                  _Metric(
                    'Bookings',
                    bookings.toString(),
                    Icons.event_available_outlined,
                  ),
                  _Metric(
                    'Gross revenue',
                    AppFormatters.money(gross),
                    Icons.trending_up_rounded,
                  ),
                  _Metric(
                    'Commission',
                    AppFormatters.money(commission),
                    Icons.percent_rounded,
                  ),
                  _Metric(
                    'Hotel payable',
                    AppFormatters.money(payable),
                    Icons.account_balance_wallet_outlined,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _RevenueChart(items: selected),
              const SizedBox(height: AppSpacing.lg),
              _FinanceTable(items: selected),
            ],
          );
        },
      ),
    );
  }
}

class HotelApprovalTab extends ConsumerStatefulWidget {
  const HotelApprovalTab({super.key});

  @override
  ConsumerState<HotelApprovalTab> createState() => _HotelApprovalTabState();
}

class _HotelApprovalTabState extends ConsumerState<HotelApprovalTab> {
  final _noteController = TextEditingController();
  String? _selectedId;
  bool _saving = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit(AdminHotel hotel, {required bool approve}) async {
    final note = _noteController.text.trim();
    if (!approve && note.isEmpty) {
      AppErrorPresenter.showSnackBar(
        context,
        'Please enter a rejection reason.',
      );
      return;
    }
    setState(() => _saving = true);
    try {
      if (approve) {
        await ref.read(platformAdminApiProvider).approveHotel(hotel.id);
      } else {
        await ref.read(platformAdminApiProvider).rejectHotel(
              hotelId: hotel.id,
              reason: note,
            );
      }
      ref.invalidate(pendingHotelsProvider);
      _noteController.clear();
      setState(() => _selectedId = null);
      if (mounted) {
        AppErrorPresenter.showSnackBar(context, 'Hotel review saved.');
      }
    } catch (error) {
      if (mounted) await AppErrorPresenter.showBottomSheet(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hotels = ref.watch(pendingHotelsProvider);
    return _AdminRefreshView(
      onRefresh: () async => ref.invalidate(pendingHotelsProvider),
      child: hotels.when(
        loading: () => const _LoadingBody(),
        error: (error, _) => _ErrorBody(
          title: 'Unable to load pending hotels',
          error: error,
          onRetry: () => ref.invalidate(pendingHotelsProvider),
        ),
        data: (items) {
          final selected = _selectedItem(
            items,
            _selectedId,
            (item) => item.id,
          );
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              const _ScreenHeading(
                title: 'Hotel Approval',
                subtitle: 'Review submitted properties before publication',
              ),
              const SizedBox(height: AppSpacing.lg),
              _SelectionPanel<AdminHotel>(
                title: 'Pending Hotel List',
                items: items,
                selectedId: selected?.id,
                idOf: (item) => item.id,
                onSelected: (item) {
                  _noteController.clear();
                  setState(() => _selectedId = item.id);
                },
                emptyMessage: 'No hotels are waiting for review.',
                itemBuilder: (item) => _SelectionRow(
                  icon: Icons.apartment_rounded,
                  title: item.name,
                  subtitle: item.city,
                  status: item.approvalStatus,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _SectionPanel(
                title: 'Hotel Detail Review',
                child: selected == null
                    ? const _SelectionHint('Select a pending hotel to review.')
                    : Column(
                        children: [
                          _DetailRow(label: 'Hotel', value: selected.name),
                          _DetailRow(
                            label: 'Address',
                            value: '${selected.addressLine}, ${selected.city}',
                          ),
                          _DetailRow(
                            label: 'Contact email',
                            value: selected.contactEmail,
                          ),
                          _DetailRow(
                            label: 'Contact phone',
                            value: selected.contactPhone,
                          ),
                          _DetailRow(
                            label: 'Publication',
                            value: selected.publicationStatus,
                          ),
                          _DetailRow(
                            label: 'Commission',
                            value: _percent(selected.defaultCommissionRate),
                            showDivider: false,
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _SectionPanel(
                title: 'Admin Note',
                child: TextField(
                  controller: _noteController,
                  enabled: selected != null && !_saving,
                  maxLength: 500,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: 'Required when rejecting',
                    alignLabelWithHint: true,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_saving)
                const LinearProgressIndicator()
              else
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: selected == null
                            ? null
                            : () => _submit(selected, approve: true),
                        icon: const Icon(Icons.check_circle_outline_rounded),
                        label: const Text('Approve'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: selected == null
                            ? null
                            : () => _submit(selected, approve: false),
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Reject'),
                      ),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class CommissionManagementTab extends ConsumerStatefulWidget {
  const CommissionManagementTab({super.key});

  @override
  ConsumerState<CommissionManagementTab> createState() =>
      _CommissionManagementTabState();
}

class _CommissionManagementTabState
    extends ConsumerState<CommissionManagementTab> {
  final _rateController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _hotelId;
  bool _saving = false;

  @override
  void dispose() {
    _rateController.dispose();
    super.dispose();
  }

  void _selectHotel(String? id, List<AdminHotel> hotels) {
    final hotel = _selectedItem(hotels, id, (item) => item.id);
    setState(() {
      _hotelId = id;
      _rateController.text = hotel == null
          ? ''
          : (hotel.defaultCommissionRate * 100).toStringAsFixed(1);
    });
  }

  Future<void> _save(AdminHotel hotel) async {
    if (_formKey.currentState?.validate() != true) return;
    setState(() => _saving = true);
    try {
      await ref.read(platformAdminApiProvider).updateCommissionRate(
            hotelId: hotel.id,
            commissionRate: double.parse(_rateController.text) / 100,
          );
      ref.invalidate(adminHotelsProvider);
      if (mounted) {
        AppErrorPresenter.showSnackBar(context, 'Commission rate updated.');
      }
    } catch (error) {
      if (mounted) await AppErrorPresenter.showBottomSheet(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hotels = ref.watch(adminHotelsProvider);
    return _AdminRefreshView(
      onRefresh: () async => ref.invalidate(adminHotelsProvider),
      child: hotels.when(
        loading: () => const _LoadingBody(),
        error: (error, _) => _ErrorBody(
          title: 'Unable to load commission settings',
          error: error,
          onRetry: () => ref.invalidate(adminHotelsProvider),
        ),
        data: (allHotels) {
          final approved = allHotels
              .where(
                (hotel) => hotel.approvalStatus.toLowerCase() == 'approved',
              )
              .toList();
          final selected = _selectedItem(approved, _hotelId, (item) => item.id);
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              const _ScreenHeading(
                title: 'Commission Management',
                subtitle: 'Configure the rate for future successful bookings',
              ),
              const SizedBox(height: AppSpacing.xl),
              DropdownButtonFormField<String>(
                initialValue: selected?.id,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Hotel selector',
                  prefixIcon: Icon(Icons.apartment_outlined),
                ),
                items: approved
                    .map(
                      (hotel) => DropdownMenuItem(
                        value: hotel.id,
                        child:
                            Text(hotel.name, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: _saving ? null : (id) => _selectHotel(id, approved),
              ),
              const SizedBox(height: AppSpacing.lg),
              _RateCard(rate: selected?.defaultCommissionRate),
              const SizedBox(height: AppSpacing.lg),
              Form(
                key: _formKey,
                child: TextFormField(
                  controller: _rateController,
                  enabled: selected != null && !_saving,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d{0,2}(\.\d{0,2})?$'),
                    ),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'New commission rate',
                    suffixText: '%',
                    helperText: 'Allowed range: 0% to 30%',
                  ),
                  validator: (value) {
                    final rate = double.tryParse(value ?? '');
                    if (rate == null || rate < 0 || rate > 30) {
                      return 'Enter a percentage from 0 to 30.';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const _ReadOnlyFilter(
                label: 'Effective date',
                value: 'Immediately after save',
                icon: Icons.calendar_today_outlined,
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton.icon(
                onPressed:
                    selected == null || _saving ? null : () => _save(selected),
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('Save Rate'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class PaymentReconciliationTab extends ConsumerStatefulWidget {
  const PaymentReconciliationTab({super.key});

  @override
  ConsumerState<PaymentReconciliationTab> createState() =>
      _PaymentReconciliationTabState();
}

class _PaymentReconciliationTabState
    extends ConsumerState<PaymentReconciliationTab> {
  final _noteController = TextEditingController();
  String? _selectedId;
  bool _saving = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _review(AdminPaymentTransaction item, String status) async {
    final note = _noteController.text.trim();
    if (status == 'Exception' && note.isEmpty) {
      AppErrorPresenter.showSnackBar(context, 'Enter an exception reason.');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(platformAdminApiProvider).updatePaymentReconciliation(
            paymentTransactionId: item.id,
            status: status,
            note: note,
          );
      ref.invalidate(unreconciledPaymentsProvider);
      _noteController.clear();
      setState(() => _selectedId = null);
      if (mounted) {
        AppErrorPresenter.showSnackBar(context, 'Reconciliation updated.');
      }
    } catch (error) {
      if (mounted) await AppErrorPresenter.showBottomSheet(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final payments = ref.watch(unreconciledPaymentsProvider);
    return _AdminRefreshView(
      onRefresh: () async => ref.invalidate(unreconciledPaymentsProvider),
      child: payments.when(
        loading: () => const _LoadingBody(),
        error: (error, _) => _ErrorBody(
          title: 'Unable to load payment reconciliation',
          error: error,
          onRetry: () => ref.invalidate(unreconciledPaymentsProvider),
        ),
        data: (items) {
          final selected = _selectedItem(items, _selectedId, (item) => item.id);
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              const _ScreenHeading(
                title: 'Payment Reconciliation',
                subtitle:
                    'Review provider transactions and record their outcome',
              ),
              const SizedBox(height: AppSpacing.lg),
              _SelectionPanel<AdminPaymentTransaction>(
                title: 'Transaction List',
                items: items,
                selectedId: selected?.id,
                idOf: (item) => item.id,
                onSelected: (item) {
                  _noteController.text = item.reconciliationNote ?? '';
                  setState(() => _selectedId = item.id);
                },
                emptyMessage: 'No payments are waiting for review.',
                itemBuilder: (item) => _SelectionRow(
                  icon: Icons.receipt_long_outlined,
                  title: item.hotelName,
                  subtitle: AppFormatters.money(item.amount),
                  status: item.status,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _SectionPanel(
                title: 'Provider Reference',
                child: selected == null
                    ? const _SelectionHint('Select a transaction to reconcile.')
                    : _DetailRow(
                        label: selected.provider,
                        value: selected.gatewayReference ?? 'Not recorded',
                        showDivider: false,
                      ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _SectionPanel(
                title: 'Amount / Status',
                child: selected == null
                    ? const _SelectionHint('No transaction selected.')
                    : Column(
                        children: [
                          _DetailRow(
                            label: 'Total amount',
                            value: AppFormatters.money(selected.amount),
                          ),
                          _DetailRow(
                            label: 'Payment status',
                            value: selected.status,
                          ),
                          _DetailRow(
                            label: 'Booking',
                            value: _shortId(selected.bookingId),
                            showDivider: false,
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _SectionPanel(
                title: 'Reconciliation Note',
                child: TextField(
                  controller: _noteController,
                  enabled: selected != null && !_saving,
                  maxLength: 500,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: 'Required when marking an exception',
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_saving)
                const LinearProgressIndicator()
              else
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: selected == null
                            ? null
                            : () => _review(selected, 'Reconciled'),
                        icon: const Icon(Icons.check_circle_outline_rounded),
                        label: const Text('Mark Reconciled'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: selected == null
                            ? null
                            : () => _review(selected, 'Exception'),
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Mark Exception'),
                      ),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class RefundManagementTab extends ConsumerStatefulWidget {
  const RefundManagementTab({super.key});

  @override
  ConsumerState<RefundManagementTab> createState() =>
      _RefundManagementTabState();
}

class _RefundManagementTabState extends ConsumerState<RefundManagementTab> {
  final _amountController = TextEditingController();
  String? _selectedId;
  bool _saving = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _setStatus(AdminRefund item, String status) async {
    final approvedAmount =
        status == 'Approved' ? double.tryParse(_amountController.text) : null;
    if (status == 'Approved' &&
        (approvedAmount == null ||
            approvedAmount < 0 ||
            approvedAmount > item.requestedAmount)) {
      AppErrorPresenter.showSnackBar(
        context,
        'Enter an amount up to the requested refund.',
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(platformAdminApiProvider).updateRefundStatus(
            refundId: item.id,
            status: status,
            approvedAmount: status == 'Rejected' ? 0 : approvedAmount,
          );
      ref.invalidate(actionableAdminRefundsProvider);
      ref.invalidate(pendingRefundsProvider);
      _amountController.clear();
      setState(() => _selectedId = null);
      if (mounted) {
        AppErrorPresenter.showSnackBar(context, 'Refund status updated.');
      }
    } catch (error) {
      if (mounted) await AppErrorPresenter.showBottomSheet(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final refunds = ref.watch(actionableAdminRefundsProvider);
    return _AdminRefreshView(
      onRefresh: () async => ref.invalidate(actionableAdminRefundsProvider),
      child: refunds.when(
        loading: () => const _LoadingBody(),
        error: (error, _) => _ErrorBody(
          title: 'Unable to load refund requests',
          error: error,
          onRetry: () => ref.invalidate(actionableAdminRefundsProvider),
        ),
        data: (items) {
          final selected = _selectedItem(items, _selectedId, (item) => item.id);
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              const _ScreenHeading(
                title: 'Refund Management',
                subtitle: 'Review and update manual refund requests',
              ),
              const SizedBox(height: AppSpacing.lg),
              _SelectionPanel<AdminRefund>(
                title: 'Refund Request List',
                items: items,
                selectedId: selected?.id,
                idOf: (item) => item.id,
                onSelected: (item) {
                  _amountController.text = (item.status == 'Approved'
                          ? item.approvedAmount
                          : item.requestedAmount)
                      .toStringAsFixed(2);
                  setState(() => _selectedId = item.id);
                },
                emptyMessage: 'No refund requests require action.',
                itemBuilder: (item) => _SelectionRow(
                  icon: Icons.receipt_long_outlined,
                  title: item.hotelName,
                  subtitle: AppFormatters.money(item.requestedAmount),
                  status: item.status,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _SectionPanel(
                title: 'Booking / Payment Detail',
                child: selected == null
                    ? const _SelectionHint('Select a refund request to review.')
                    : Column(
                        children: [
                          _DetailRow(label: 'Hotel', value: selected.hotelName),
                          _DetailRow(
                            label: 'Booking',
                            value: _shortId(selected.bookingId),
                          ),
                          _DetailRow(label: 'Reason', value: selected.reason),
                          _DetailRow(
                            label: 'Requested',
                            value:
                                AppFormatters.money(selected.requestedAmount),
                            showDivider: false,
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _amountController,
                enabled: selected != null && !_saving,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'^\d*(\.\d{0,2})?$'),
                  ),
                ],
                decoration: const InputDecoration(
                  labelText: 'Approved amount',
                  prefixText: '\$ ',
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_saving)
                const LinearProgressIndicator()
              else if (selected?.status == 'Approved')
                FilledButton.icon(
                  onPressed: selected == null
                      ? null
                      : () => _setStatus(selected, 'Processed'),
                  icon: const Icon(Icons.schedule_outlined),
                  label: const Text('Mark Processed'),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: selected == null
                            ? null
                            : () => _setStatus(selected, 'Approved'),
                        icon: const Icon(Icons.check_circle_outline_rounded),
                        label: const Text('Approve'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: selected == null
                            ? null
                            : () => _setStatus(selected, 'Rejected'),
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Reject'),
                      ),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class SettlementManagementTab extends ConsumerStatefulWidget {
  const SettlementManagementTab({super.key});

  @override
  ConsumerState<SettlementManagementTab> createState() =>
      _SettlementManagementTabState();
}

class _SettlementManagementTabState
    extends ConsumerState<SettlementManagementTab> {
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  final _noteController = TextEditingController();
  String? _selectedId;
  DateTime? _date;
  bool _saving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _select(AdminSettlement item) {
    _amountController.text = item.expectedAmount.toStringAsFixed(2);
    _referenceController.text = item.reference;
    _noteController.text = item.adminNote ?? '';
    setState(() {
      _selectedId = item.id;
      _date = item.settlementDateUtc?.toLocal() ?? DateTime.now();
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDate: _date ?? now,
    );
    if (date != null) setState(() => _date = date);
  }

  Future<void> _mark(AdminSettlement item) async {
    final amount = double.tryParse(_amountController.text);
    final reference = _referenceController.text.trim();
    if (amount == null || reference.isEmpty || _date == null) {
      AppErrorPresenter.showSnackBar(
        context,
        'Enter the actual amount, reference, and date.',
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(platformAdminApiProvider).updateSettlementStatus(
            settlementId: item.id,
            status: 'Settled',
            settledAmount: amount,
            settlementDateUtc: _date,
            reference: reference,
            adminNote: _noteController.text.trim(),
          );
      ref.invalidate(settlementsProvider);
      setState(() => _selectedId = null);
      if (mounted) {
        AppErrorPresenter.showSnackBar(context, 'Settlement updated.');
      }
    } catch (error) {
      if (mounted) await AppErrorPresenter.showBottomSheet(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _markException(AdminSettlement item) async {
    final note = _noteController.text.trim();
    if (note.isEmpty) {
      AppErrorPresenter.showSnackBar(
        context,
        'Enter an exception reason in the admin note.',
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(platformAdminApiProvider).updateSettlementStatus(
            settlementId: item.id,
            status: 'Exception',
            adminNote: note,
          );
      ref.invalidate(settlementsProvider);
      setState(() => _selectedId = null);
      if (mounted) {
        AppErrorPresenter.showSnackBar(
          context,
          'Settlement exception recorded.',
        );
      }
    } catch (error) {
      if (mounted) await AppErrorPresenter.showBottomSheet(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settlements = ref.watch(settlementsProvider);
    return _AdminRefreshView(
      onRefresh: () async => ref.invalidate(settlementsProvider),
      child: settlements.when(
        loading: () => const _LoadingBody(),
        error: (error, _) => _ErrorBody(
          title: 'Unable to load settlements',
          error: error,
          onRetry: () => ref.invalidate(settlementsProvider),
        ),
        data: (items) {
          final eligible =
              items.where((item) => item.status == 'Pending').toList();
          final selected =
              _selectedItem(eligible, _selectedId, (item) => item.id);
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              const _ScreenHeading(
                title: 'Settlement Management',
                subtitle: 'Record hotel payouts and commission collections',
              ),
              const SizedBox(height: AppSpacing.lg),
              _SelectionPanel<AdminSettlement>(
                title: 'Eligible Settlement Records',
                items: eligible,
                selectedId: selected?.id,
                idOf: (item) => item.id,
                onSelected: _select,
                emptyMessage: 'No settlement records are eligible.',
                itemBuilder: (item) => _SelectionRow(
                  icon: Icons.receipt_long_outlined,
                  title: item.hotelName,
                  subtitle: AppFormatters.money(item.expectedAmount),
                  status: 'Eligible',
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _ReadOnlyFilter(
                label: 'Settlement type',
                value: selected == null
                    ? 'Select a record'
                    : _settlementType(selected),
                icon: Icons.account_balance_outlined,
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: _AmountSummary(
                      label: 'Expected amount',
                      value: selected == null
                          ? '-'
                          : AppFormatters.money(selected.expectedAmount),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextField(
                      controller: _amountController,
                      enabled: selected != null && !_saving,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*(\.\d{0,2})?$'),
                        ),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Actual amount',
                        prefixText: '\$ ',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _referenceController,
                enabled: selected != null && !_saving,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Reference',
                  prefixIcon: Icon(Icons.tag_rounded),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              InkWell(
                onTap: selected == null || _saving ? null : _pickDate,
                borderRadius: BorderRadius.circular(AppRadii.sm),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Settlement date',
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  child:
                      Text(_date == null ? 'Select date' : _formatDate(_date!)),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _SectionPanel(
                title: 'Admin Note',
                child: TextField(
                  controller: _noteController,
                  enabled: selected != null && !_saving,
                  maxLength: 500,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(hintText: 'Optional note'),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed:
                    selected == null || _saving ? null : () => _mark(selected),
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.account_balance_outlined),
                label: const Text('Mark Settlement'),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: selected == null || _saving
                    ? null
                    : () => _markException(selected),
                icon: const Icon(Icons.report_problem_outlined),
                label: const Text('Record Exception'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AdminRefreshView extends StatelessWidget {
  const _AdminRefreshView({required this.onRefresh, required this.child});

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(onRefresh: onRefresh, child: child);
  }
}

class _ScreenHeading extends StatelessWidget {
  const _ScreenHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _SectionPanel extends StatelessWidget {
  const _SectionPanel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.outline),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _SelectionPanel<T> extends StatelessWidget {
  const _SelectionPanel({
    required this.title,
    required this.items,
    required this.selectedId,
    required this.idOf,
    required this.onSelected,
    required this.emptyMessage,
    required this.itemBuilder,
  });

  final String title;
  final List<T> items;
  final String? selectedId;
  final String Function(T item) idOf;
  final ValueChanged<T> onSelected;
  final String emptyMessage;
  final Widget Function(T item) itemBuilder;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.outline),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          const Divider(height: 1),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(emptyMessage, textAlign: TextAlign.center),
            )
          else
            for (var index = 0; index < items.length; index++) ...[
              Material(
                color: idOf(items[index]) == selectedId
                    ? AppColors.surfaceSoft
                    : Colors.transparent,
                child: InkWell(
                  onTap: () => onSelected(items[index]),
                  child: itemBuilder(items[index]),
                ),
              ),
              if (index < items.length - 1) const Divider(height: 1),
            ],
        ],
      ),
    );
  }
}

class _SelectionRow extends StatelessWidget {
  const _SelectionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Icon(icon, color: AppColors.mutedInk),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _StatusBadge(status),
          const SizedBox(width: AppSpacing.xs),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.status);

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final positive = normalized == 'approved' ||
        normalized == 'paid' ||
        normalized == 'eligible' ||
        normalized == 'reconciled';
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: positive ? AppColors.successSoft : AppColors.warningSoft,
        borderRadius: BorderRadius.circular(AppRadii.xs),
      ),
      child: Text(
        status,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: positive ? AppColors.success : AppColors.warning,
            ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 112,
                child:
                    Text(label, style: Theme.of(context).textTheme.bodySmall),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  value.isEmpty ? 'Not recorded' : value,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
        if (showDivider) const Divider(height: 1),
      ],
    );
  }
}

class _SelectionHint extends StatelessWidget {
  const _SelectionHint(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Text(message, textAlign: TextAlign.center),
    );
  }
}

class _ReadOnlyFilter extends StatelessWidget {
  const _ReadOnlyFilter({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

class _RateCard extends StatelessWidget {
  const _RateCard({required this.rate});
  final double? rate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        border: Border.all(color: AppColors.outline),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current Commission Rate',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            rate == null ? '-' : _percent(rate!),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ],
      ),
    );
  }
}

class _AmountSummary extends StatelessWidget {
  const _AmountSummary({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.outline),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: AppSpacing.xxs),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics});
  final List<_Metric> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - AppSpacing.sm) / 2;
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final metric in metrics)
              SizedBox(width: width, child: _MetricCard(metric: metric)),
          ],
        );
      },
    );
  }
}

class _Metric {
  const _Metric(this.label, this.value, this.icon);
  final String label;
  final String value;
  final IconData icon;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});
  final _Metric metric;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 120),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.outline),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.surfaceSoft,
            foregroundColor: AppColors.brand,
            child: Icon(metric.icon),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metric.label,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.xxs),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    metric.value,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RevenueChart extends StatelessWidget {
  const _RevenueChart({required this.items});
  final List<AdminFinanceSummary> items;

  @override
  Widget build(BuildContext context) {
    final ranked = [...items]
      ..sort((a, b) => b.grossBookingRevenue.compareTo(a.grossBookingRevenue));
    final visible = ranked.take(6).toList();
    final maximum = visible.fold<double>(
      0,
      (value, item) =>
          item.grossBookingRevenue > value ? item.grossBookingRevenue : value,
    );
    return _SectionPanel(
      title: 'Revenue by hotel',
      child: visible.isEmpty
          ? const _SelectionHint('No dashboard data is available.')
          : Column(
              children: [
                for (final item in visible) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _hotelName(item.hotelName),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(AppFormatters.money(item.grossBookingRevenue)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.xs),
                    child: LinearProgressIndicator(
                      minHeight: 12,
                      value:
                          maximum == 0 ? 0 : item.grossBookingRevenue / maximum,
                      backgroundColor: AppColors.surfaceSoft,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ],
            ),
    );
  }
}

class _FinanceTable extends StatelessWidget {
  const _FinanceTable({required this.items});
  final List<AdminFinanceSummary> items;

  @override
  Widget build(BuildContext context) {
    return _SectionPanel(
      title: 'Hotel performance',
      child: items.isEmpty
          ? const _SelectionHint('No hotel performance data is available.')
          : Column(
              children: [
                for (var index = 0; index < items.length; index++)
                  _DetailRow(
                    label: _hotelName(items[index].hotelName),
                    value:
                        '${items[index].successfulBookingCount} bookings  |  ${AppFormatters.money(items[index].grossBookingRevenue)}',
                    showDivider: index < items.length - 1,
                  ),
              ],
            ),
    );
  }
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: const [
        AppShimmer(
          child: Column(
            children: [
              ShimmerBlock(width: double.infinity, height: 40),
              SizedBox(height: AppSpacing.lg),
              ShimmerBlock(width: double.infinity, height: 160),
              SizedBox(height: AppSpacing.md),
              ShimmerBlock(width: double.infinity, height: 240),
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({
    required this.title,
    required this.error,
    required this.onRetry,
  });

  final String title;
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const SizedBox(height: AppSpacing.section),
        Icon(
          Icons.cloud_off_outlined,
          size: 48,
          color: Theme.of(context).colorScheme.error,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          AppErrorPresenter.friendlyMessage(error),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ),
      ],
    );
  }
}

T? _selectedItem<T>(
  List<T> items,
  String? selectedId,
  String Function(T item) idOf,
) {
  if (selectedId == null) return null;
  for (final item in items) {
    if (idOf(item) == selectedId) return item;
  }
  return null;
}

String _hotelName(String value) =>
    value.trim().isEmpty ? 'Unnamed hotel' : value.trim();

String _percent(double value) => '${(value * 100).toStringAsFixed(1)}%';

String _shortId(String value) {
  final normalized = value.replaceAll('-', '').toUpperCase();
  return normalized.length <= 8 ? normalized : normalized.substring(0, 8);
}

String _settlementType(AdminSettlement item) =>
    item.settlementType == 'HotelPayable'
        ? 'Hotel settlement'
        : 'Commission collection';

String _formatDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
