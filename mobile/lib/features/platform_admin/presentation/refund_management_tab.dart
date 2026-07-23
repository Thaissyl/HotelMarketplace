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

final actionableAdminRefundsProvider =
    FutureProvider.autoDispose<List<AdminRefund>>((ref) async {
  final api = ref.watch(platformAdminApiProvider);
  final groups = await Future.wait([
    api.getRefunds(status: 'PendingReview'),
    api.getRefunds(status: 'Approved'),
    api.getRefunds(status: 'Processed'),
    api.getRefunds(status: 'Rejected'),
  ]);
  final refunds = groups.expand((group) => group).toList()
    ..sort((left, right) => right.createdAtUtc.compareTo(left.createdAtUtc));
  return refunds;
});

class RefundManagementTab extends ConsumerStatefulWidget {
  const RefundManagementTab({super.key});

  @override
  ConsumerState<RefundManagementTab> createState() =>
      _RefundManagementTabState();
}

class _RefundManagementTabState extends ConsumerState<RefundManagementTab> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _selectedId;
  int _page = 0;
  bool _saving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _select(AdminRefund item) {
    _amountController.text =
        (item.approvedAmount > 0 ? item.approvedAmount : item.requestedAmount)
            .toStringAsFixed(2);
    _noteController.clear();
    setState(() => _selectedId = item.id);
  }

  void _changePage(int page) {
    _amountController.clear();
    _noteController.clear();
    setState(() {
      _page = page;
      _selectedId = null;
    });
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
      if (!mounted) return;
      _amountController.clear();
      _noteController.clear();
      setState(() => _selectedId = null);
      AppErrorPresenter.showSnackBar(context, 'Refund status updated.');
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
    final refunds = ref.watch(actionableAdminRefundsProvider);
    return AdminRefreshView(
      onRefresh: () async => ref.invalidate(actionableAdminRefundsProvider),
      child: refunds.when(
        loading: () => const AdminLoadingBody(),
        error: (error, _) => AdminErrorBody(
          title: 'Unable to load refund requests',
          error: error,
          onRetry: () => ref.invalidate(actionableAdminRefundsProvider),
        ),
        data: (items) {
          final selected = adminSelectedItem(
            items,
            _selectedId,
            (item) => item.id,
          );
          final validPage = adminValidPage(
            _page,
            items.length,
            adminListPageSize,
          );
          final visible = adminPage(items, validPage, adminListPageSize);
          final selectedStatus = selected?.status.toLowerCase();
          final isPending = selectedStatus == 'pendingreview';
          final isApproved = selectedStatus == 'approved';

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              AdminRecordList(
                title: 'Refund Request List',
                emptyMessage: 'No refund requests are available.',
                rows: [
                  for (final item in visible)
                    AdminRecordRow(
                      title: 'Refund Request ${adminShortId(item.id)}',
                      subtitle:
                          '${adminHotelName(item.hotelName)} | ${AppFormatters.money(item.requestedAmount)}',
                      status: _refundStatusLabel(item.status),
                      selected: selected?.id == item.id,
                      onTap: () => _select(item),
                    ),
                ],
                footer: items.length > adminListPageSize
                    ? AdminPaginationBar(
                        page: validPage,
                        pageCount: adminPageCount(
                          items.length,
                          adminListPageSize,
                        ),
                        onPageChanged: _changePage,
                      )
                    : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              AdminPanel(
                title: 'Booking / Payment Detail',
                child: selected == null
                    ? const AdminSelectionHint(
                        'Select a refund request to review.',
                      )
                    : Column(
                        children: [
                          AdminDetailRow(
                            label: 'Hotel',
                            value: adminHotelName(selected.hotelName),
                          ),
                          AdminDetailRow(
                            label: 'Booking',
                            value: adminShortId(selected.bookingId),
                          ),
                          AdminDetailRow(
                            label: 'Reason',
                            value: selected.reason,
                          ),
                          AdminDetailRow(
                            label: 'Requested',
                            value:
                                AppFormatters.money(selected.requestedAmount),
                          ),
                          AdminDetailRow(
                            label: 'Approved',
                            value: AppFormatters.money(selected.approvedAmount),
                            showDivider: false,
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _ApprovedAmountField(
                controller: _amountController,
                enabled: selected != null && isPending && !_saving,
              ),
              const SizedBox(height: AppSpacing.lg),
              AdminTextArea(
                label: 'Admin Note',
                controller: _noteController,
                enabled: false,
                hintText: 'Not supported by the current refund API',
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_saving)
                const LinearProgressIndicator()
              else ...[
                FilledButton.icon(
                  onPressed: isPending && selected != null
                      ? () => _setStatus(selected, 'Approved')
                      : null,
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('Approve'),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: isPending && selected != null
                      ? () => _setStatus(selected, 'Rejected')
                      : null,
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Reject'),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: isApproved && selected != null
                      ? () => _setStatus(selected, 'Processed')
                      : null,
                  icon: const Icon(Icons.schedule_outlined),
                  label: const Text('Mark Processed'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ApprovedAmountField extends StatelessWidget {
  const _ApprovedAmountField({
    required this.controller,
    required this.enabled,
  });

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.outlineSoft),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Approved Amount',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: controller,
            enabled: enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                RegExp(r'^\d*(\.\d{0,2})?$'),
              ),
            ],
            decoration: const InputDecoration(prefixText: '\$ '),
          ),
        ],
      ),
    );
  }
}

String _refundStatusLabel(String status) {
  return status.toLowerCase() == 'pendingreview' ? 'Pending' : status;
}
