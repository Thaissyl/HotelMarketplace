import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../shared/utils/app_formatters.dart';
import '../../../shared/widgets/app_error_presenter.dart';
import '../application/platform_admin_providers.dart';
import '../domain/platform_admin_models.dart';
import 'admin_srs_components.dart';

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
  int _page = 0;
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

  void _changePage(int page) {
    _clearSelection();
    setState(() => _page = page);
  }

  void _clearSelection() {
    _amountController.clear();
    _referenceController.clear();
    _noteController.clear();
    _selectedId = null;
    _date = null;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDate: _date ?? now,
    );
    if (date != null && mounted) setState(() => _date = date);
  }

  Future<void> _mark(AdminSettlement item) async {
    final amount = double.tryParse(_amountController.text);
    final reference = _referenceController.text.trim();
    final note = _noteController.text.trim();
    if (amount == null || amount < 0 || reference.isEmpty || _date == null) {
      AppErrorPresenter.showSnackBar(
        context,
        'Enter the actual amount, reference, and date.',
      );
      return;
    }
    if ((amount - item.expectedAmount).abs() >= 0.01 && note.isEmpty) {
      AppErrorPresenter.showSnackBar(
        context,
        'Explain the amount difference in the admin note.',
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
            adminNote: note,
          );
      ref.invalidate(settlementsProvider);
      if (!mounted) return;
      setState(_clearSelection);
      AppErrorPresenter.showSnackBar(context, 'Settlement updated.');
    } catch (error) {
      if (mounted) {
        await AppErrorPresenter.showBottomSheet(context, error);
      }
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
      if (!mounted) return;
      setState(_clearSelection);
      AppErrorPresenter.showSnackBar(
        context,
        'Settlement exception recorded.',
      );
    } catch (error) {
      if (mounted) {
        await AppErrorPresenter.showBottomSheet(context, error);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settlements = ref.watch(settlementsProvider);
    return AdminRefreshView(
      onRefresh: () async => ref.invalidate(settlementsProvider),
      child: settlements.when(
        loading: () => const AdminLoadingBody(),
        error: (error, _) => AdminErrorBody(
          title: 'Unable to load settlements',
          error: error,
          onRetry: () => ref.invalidate(settlementsProvider),
        ),
        data: (items) {
          final eligible = items
              .where((item) => item.status.toLowerCase() == 'pending')
              .toList(growable: false);
          final selected = adminSelectedItem(
            eligible,
            _selectedId,
            (item) => item.id,
          );
          final validPage = adminValidPage(
            _page,
            eligible.length,
            adminListPageSize,
          );
          final visible = adminPage(
            eligible,
            validPage,
            adminListPageSize,
          );

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              AdminRecordList(
                title: 'Eligible Settlement Records',
                emptyMessage: 'No settlement records are eligible.',
                rows: [
                  for (final item in visible)
                    AdminRecordRow(
                      title: 'Settlement ${adminShortId(item.id)}',
                      subtitle:
                          '${adminHotelName(item.hotelName)} | ${AppFormatters.money(item.expectedAmount)}',
                      status: 'Eligible',
                      selected: selected?.id == item.id,
                      onTap: () => _select(item),
                    ),
                ],
                footer: eligible.length > adminListPageSize
                    ? AdminPaginationBar(
                        page: validPage,
                        pageCount: adminPageCount(
                          eligible.length,
                          adminListPageSize,
                        ),
                        onPageChanged: _changePage,
                      )
                    : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              _SettlementTypeField(item: selected),
              const SizedBox(height: AppSpacing.lg),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _AmountSummary(
                      label: 'Expected Amount',
                      value: selected == null
                          ? '-'
                          : AppFormatters.money(selected.expectedAmount),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _ActualAmountField(
                      controller: _amountController,
                      enabled: selected != null && !_saving,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _ReferenceDatePanel(
                referenceController: _referenceController,
                enabled: selected != null && !_saving,
                date: _date,
                onPickDate: _pickDate,
              ),
              const SizedBox(height: AppSpacing.lg),
              AdminTextArea(
                label: 'Admin Note',
                controller: _noteController,
                enabled: selected != null && !_saving,
                hintText:
                    'Optional unless recording an exception or amount difference',
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed:
                    selected == null || _saving ? null : () => _mark(selected),
                child: _saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.surface,
                        ),
                      )
                    : const Text('Mark Settlement'),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                onPressed: selected == null || _saving
                    ? null
                    : () => _markException(selected),
                child: const Text('Record Exception'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SettlementTypeField extends StatelessWidget {
  const _SettlementTypeField({required this.item});

  final AdminSettlement? item;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 96),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.outline),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Settlement Type',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  item == null
                      ? 'Select an eligible record'
                      : _settlementType(item!),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.mutedInk,
                      ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.mutedInk,
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
      height: 112,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.outlineSoft),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleSmall),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActualAmountField extends StatelessWidget {
  const _ActualAmountField({
    required this.controller,
    required this.enabled,
  });

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 112,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.outlineSoft),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Actual Amount',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const Spacer(),
          TextField(
            controller: controller,
            enabled: enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                RegExp(r'^\d*(\.\d{0,2})?$'),
              ),
            ],
            decoration: const InputDecoration(
              prefixText: '\$ ',
              isDense: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferenceDatePanel extends StatelessWidget {
  const _ReferenceDatePanel({
    required this.referenceController,
    required this.enabled,
    required this.date,
    required this.onPickDate,
  });

  final TextEditingController referenceController;
  final bool enabled;
  final DateTime? date;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.outline),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reference / Date',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: referenceController,
            enabled: enabled,
            maxLength: 100,
            decoration: const InputDecoration(
              hintText: 'Bank or internal reference',
              counterText: '',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          InkWell(
            onTap: enabled ? onPickDate : null,
            borderRadius: BorderRadius.circular(AppRadii.sm),
            child: InputDecorator(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.calendar_today_outlined),
                suffixIcon: Icon(Icons.keyboard_arrow_down_rounded),
              ),
              child: Text(
                date == null ? 'Select settlement date' : adminDate(date!),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _settlementType(AdminSettlement item) {
  return item.settlementType == 'HotelPayable'
      ? 'Hotel settlement'
      : 'Commission collection';
}
