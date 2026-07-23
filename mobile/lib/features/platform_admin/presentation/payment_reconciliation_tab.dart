import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../shared/utils/app_formatters.dart';
import '../../../shared/widgets/app_error_presenter.dart';
import '../application/platform_admin_providers.dart';
import '../domain/platform_admin_models.dart';
import 'admin_srs_components.dart';

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
  int _page = 0;
  bool _saving = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _select(AdminPaymentTransaction item) {
    _noteController.text = item.reconciliationNote ?? '';
    setState(() => _selectedId = item.id);
  }

  void _changePage(int page) {
    _noteController.clear();
    setState(() {
      _page = page;
      _selectedId = null;
    });
  }

  Future<void> _review(
    AdminPaymentTransaction item,
    String status,
  ) async {
    final note = _noteController.text.trim();
    if (status == 'Exception' && note.isEmpty) {
      AppErrorPresenter.showSnackBar(
        context,
        'Enter an exception reason.',
      );
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
      if (!mounted) return;
      _noteController.clear();
      setState(() => _selectedId = null);
      AppErrorPresenter.showSnackBar(context, 'Reconciliation updated.');
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
    final payments = ref.watch(unreconciledPaymentsProvider);
    return AdminRefreshView(
      onRefresh: () async => ref.invalidate(unreconciledPaymentsProvider),
      child: payments.when(
        loading: () => const AdminLoadingBody(),
        error: (error, _) => AdminErrorBody(
          title: 'Unable to load payment reconciliation',
          error: error,
          onRetry: () => ref.invalidate(unreconciledPaymentsProvider),
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

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              AdminRecordList(
                title: 'Transaction List',
                emptyMessage: 'No payments are waiting for review.',
                rows: [
                  for (final item in visible)
                    AdminRecordRow(
                      title: 'Transaction ${adminShortId(item.id)}',
                      subtitle:
                          '${adminHotelName(item.hotelName)} | ${AppFormatters.money(item.amount)}',
                      status: item.reconciliationStatus.trim().isEmpty
                          ? 'Unreconciled'
                          : item.reconciliationStatus,
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
              _ProviderReference(item: selected),
              const SizedBox(height: AppSpacing.lg),
              AdminPanel(
                title: 'Amount / Status',
                child: selected == null
                    ? const AdminSelectionHint(
                        'Select a transaction to reconcile.',
                      )
                    : Column(
                        children: [
                          AdminDetailRow(
                            label: 'Total Amount',
                            value: AppFormatters.money(selected.amount),
                          ),
                          AdminDetailRow(
                            label: 'Payment Status',
                            value: selected.status,
                          ),
                          AdminDetailRow(
                            label: 'Reconciliation',
                            value: selected.reconciliationStatus,
                            showDivider: false,
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AdminTextArea(
                label: 'Reconciliation Note',
                controller: _noteController,
                enabled: selected != null && !_saving,
                hintText: 'Required when marking an exception',
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
                    const SizedBox(width: AppSpacing.md),
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

class _ProviderReference extends StatelessWidget {
  const _ProviderReference({required this.item});

  final AdminPaymentTransaction? item;

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
                  'Provider Reference',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  item == null
                      ? 'Select a transaction'
                      : '${item!.provider}: ${item!.gatewayReference ?? 'Not recorded'}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
