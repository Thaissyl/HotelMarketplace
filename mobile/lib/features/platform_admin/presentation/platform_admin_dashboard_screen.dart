import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/network/api_exception.dart';
import '../../auth/application/auth_controller.dart';
import '../../../shared/utils/app_formatters.dart';
import '../../../shared/widgets/app_error_presenter.dart';
import '../../../shared/widgets/app_shimmer.dart';
import '../application/platform_admin_providers.dart';
import '../domain/platform_admin_models.dart';

class PlatformAdminDashboardScreen extends ConsumerWidget {
  const PlatformAdminDashboardScreen({super.key});

  static const String routeName = 'platform-admin';
  static const String routePath = '/platform-admin';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Platform Admin'),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            tabs: [
              Tab(icon: Icon(Icons.analytics_rounded), text: 'Analytics'),
              Tab(
                icon: Icon(Icons.domain_verification_rounded),
                text: 'Hotels',
              ),
              Tab(
                icon: Icon(Icons.account_balance_wallet_rounded),
                text: 'Settlements',
              ),
              Tab(
                icon: Icon(Icons.replay_circle_filled_rounded),
                text: 'Refunds',
              ),
            ],
          ),
        ),
        body: const SafeArea(
          child: TabBarView(
            children: [
              _AnalyticsTab(),
              _HotelReviewTab(),
              _SettlementsTab(),
              _RefundsTab(),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnalyticsTab extends ConsumerStatefulWidget {
  const _AnalyticsTab();

  @override
  ConsumerState<_AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends ConsumerState<_AnalyticsTab> {
  static const int _pageSize = 5;

  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';
  int _pageIndex = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _setSearchTerm(String value) {
    setState(() {
      _searchTerm = value.trim().toLowerCase();
      _pageIndex = 0;
    });
  }

  void _goToPage(int pageIndex, int pageCount) {
    setState(() {
      _pageIndex = pageIndex.clamp(0, pageCount - 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(adminFinanceSummaryProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(adminFinanceSummaryProvider),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          Text(
            'Financial overview',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.xl),
          summary.when(
            data: (items) {
              final gross = items.fold<double>(
                0,
                (total, item) => total + item.grossBookingRevenue,
              );
              final commission = items.fold<double>(
                0,
                (total, item) => total + item.platformCommission,
              );
              final net = items.fold<double>(
                0,
                (total, item) => total + item.hotelNetReceivable,
              );
              final bookings = items.fold<int>(
                0,
                (total, item) => total + item.successfulBookingCount,
              );

              return Column(
                children: [
                  _KpiGrid(
                    cards: [
                      _KpiData(
                        'Gross revenue',
                        AppFormatters.money(gross),
                        'Total confirmed booking value',
                        Icons.trending_up_rounded,
                      ),
                      _KpiData(
                        'Commission',
                        AppFormatters.money(commission),
                        'Platform fee collected',
                        Icons.percent_rounded,
                      ),
                      _KpiData(
                        'Hotel payable',
                        AppFormatters.money(net),
                        'Amount owed to hotels',
                        Icons.account_balance_rounded,
                      ),
                      _KpiData(
                        'Bookings',
                        bookings.toString(),
                        'Successful reservations',
                        Icons.confirmation_number_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _FinanceHotelPagedList(
                    items: items,
                    pageSize: _pageSize,
                    pageIndex: _pageIndex,
                    searchController: _searchController,
                    searchTerm: _searchTerm,
                    onSearchChanged: _setSearchTerm,
                    onPageChanged: _goToPage,
                  ),
                ],
              );
            },
            error: (error, stackTrace) => _AdminErrorCard(
              message: 'Unable to load finance summary.',
              error: error,
              onRetry: () => ref.invalidate(adminFinanceSummaryProvider),
            ),
            loading: () => const _AdminShimmerGrid(),
          ),
        ],
      ),
    );
  }
}

class _HotelReviewTab extends ConsumerWidget {
  const _HotelReviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hotels = ref.watch(pendingHotelsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(pendingHotelsProvider),
      child: hotels.when(
        data: (items) => ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            Text(
              'Pending hotel reviews',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.xl),
            if (items.isEmpty)
              const _EmptyAdminCard(
                message: 'No hotels are waiting for review.',
              )
            else
              for (final hotel in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _HotelReviewCard(hotel: hotel),
                ),
          ],
        ),
        error: (error, stackTrace) => _AdminErrorCard(
          message: 'Unable to load pending hotels.',
          error: error,
          onRetry: () => ref.invalidate(pendingHotelsProvider),
        ),
        loading: () => const _PaddedShimmer(),
      ),
    );
  }
}

class _SettlementsTab extends ConsumerWidget {
  const _SettlementsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settlements = ref.watch(settlementsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(settlementsProvider),
      child: settlements.when(
        data: (items) => ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            Text(
              'Settlements',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.xl),
            if (items.isEmpty)
              const _EmptyAdminCard(message: 'No settlement records found.')
            else
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _SettlementCard(item: item),
                ),
          ],
        ),
        error: (error, stackTrace) => _AdminErrorCard(
          message: 'Unable to load settlements.',
          error: error,
          onRetry: () => ref.invalidate(settlementsProvider),
        ),
        loading: () => const _PaddedShimmer(),
      ),
    );
  }
}

class _RefundsTab extends ConsumerWidget {
  const _RefundsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final refunds = ref.watch(pendingRefundsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(pendingRefundsProvider),
      child: refunds.when(
        data: (items) => ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            Text(
              'Pending refunds',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.xl),
            if (items.isEmpty)
              const _EmptyAdminCard(message: 'No refund requests are pending.')
            else
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _RefundCard(item: item),
                ),
          ],
        ),
        error: (error, stackTrace) => _AdminErrorCard(
          message: 'Unable to load refunds.',
          error: error,
          onRetry: () => ref.invalidate(pendingRefundsProvider),
        ),
        loading: () => const _PaddedShimmer(),
      ),
    );
  }
}

class _HotelReviewCard extends ConsumerStatefulWidget {
  const _HotelReviewCard({required this.hotel});

  final AdminHotel hotel;

  @override
  ConsumerState<_HotelReviewCard> createState() => _HotelReviewCardState();
}

class _HotelReviewCardState extends ConsumerState<_HotelReviewCard> {
  bool _loading = false;

  Future<void> _approve() async {
    setState(() => _loading = true);
    try {
      await ref.read(platformAdminApiProvider).approveHotel(widget.hotel.id);
      ref.invalidate(pendingHotelsProvider);
    } catch (error) {
      if (mounted) {
        await AppErrorPresenter.showBottomSheet(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _reject() async {
    final reason = await _showTextDialog(
      context: context,
      title: 'Reject hotel',
      label: 'Reason',
    );
    if (reason == null || reason.trim().isEmpty) {
      return;
    }

    setState(() => _loading = true);
    try {
      await ref.read(platformAdminApiProvider).rejectHotel(
            hotelId: widget.hotel.id,
            reason: reason,
          );
      ref.invalidate(pendingHotelsProvider);
    } catch (error) {
      if (mounted) {
        await AppErrorPresenter.showBottomSheet(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hotel = widget.hotel;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(hotel.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text('${hotel.city} · ${hotel.addressLine}'),
            Text('${hotel.contactEmail} · ${hotel.contactPhone}'),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Commission: ${(hotel.defaultCommissionRate * 100).toStringAsFixed(1)}%',
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_loading)
              const LinearProgressIndicator()
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _reject,
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _approve,
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Approve'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _SettlementCard extends ConsumerStatefulWidget {
  const _SettlementCard({required this.item});
  final AdminSettlement item;
  @override
  ConsumerState<_SettlementCard> createState() => _SettlementCardState();
}

class _SettlementCardState extends ConsumerState<_SettlementCard> {
  bool _loading = false;
  Future<void> _setStatus(String status) async {
    setState(() => _loading = true);
    try {
      await ref.read(platformAdminApiProvider).updateSettlementStatus(
            settlementId: widget.item.id,
            status: status,
            adminNote: 'Updated from mobile admin dashboard',
          );
      ref.invalidate(settlementsProvider);
    } catch (error) {
      if (mounted) {
        await AppErrorPresenter.showBottomSheet(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.hotelName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${item.settlementType} · ${item.status} · ${item.items.length} items',
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              AppFormatters.money(item.totalAmount),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_loading)
              const LinearProgressIndicator()
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: item.status == 'Pending'
                          ? () => _setStatus('Exception')
                          : null,
                      child: const Text('Exception'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: item.status == 'Pending'
                          ? () => _setStatus('Settled')
                          : null,
                      child: const Text('Mark settled'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _RefundCard extends ConsumerStatefulWidget {
  const _RefundCard({required this.item});
  final AdminRefund item;
  @override
  ConsumerState<_RefundCard> createState() => _RefundCardState();
}

class _RefundCardState extends ConsumerState<_RefundCard> {
  bool _loading = false;

  Future<void> _setStatus(String status, {double? amount}) async {
    setState(() => _loading = true);
    try {
      await ref.read(platformAdminApiProvider).updateRefundStatus(
            refundId: widget.item.id,
            status: status,
            approvedAmount: amount,
          );
      ref.invalidate(pendingRefundsProvider);
    } catch (error) {
      if (mounted) {
        await AppErrorPresenter.showBottomSheet(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.hotelName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text('Booking ${item.bookingId}'),
            Text(item.reason),
            const SizedBox(height: AppSpacing.sm),
            Text('Requested ${AppFormatters.money(item.requestedAmount)}'),
            const SizedBox(height: AppSpacing.lg),
            if (_loading)
              const LinearProgressIndicator()
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _setStatus('Rejected', amount: 0),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _setStatus(
                        'Approved',
                        amount: item.requestedAmount,
                      ),
                      child: const Text('Approve'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.cards});
  final List<_KpiData> cards;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        childAspectRatio: 1.08,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
      ),
      itemBuilder: (context, index) => _KpiCard(data: cards[index]),
    );
  }
}

class _KpiData {
  const _KpiData(this.label, this.value, this.helperText, this.icon);
  final String label;
  final String value;
  final String helperText;
  final IconData icon;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.data});
  final _KpiData data;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(data.icon, color: AppColors.brand),
            const Spacer(),
            Text(data.value, style: Theme.of(context).textTheme.titleLarge),
            Text(data.label, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              data.helperText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _FinanceHotelPagedList extends StatelessWidget {
  const _FinanceHotelPagedList({
    required this.items,
    required this.pageSize,
    required this.pageIndex,
    required this.searchController,
    required this.searchTerm,
    required this.onSearchChanged,
    required this.onPageChanged,
  });

  final List<AdminFinanceSummary> items;
  final int pageSize;
  final int pageIndex;
  final TextEditingController searchController;
  final String searchTerm;
  final ValueChanged<String> onSearchChanged;
  final void Function(int pageIndex, int pageCount) onPageChanged;

  @override
  Widget build(BuildContext context) {
    final filteredItems = items.where((item) {
      if (searchTerm.isEmpty) {
        return true;
      }

      final searchableText = '${item.hotelName} ${item.hotelId}'.toLowerCase();
      return searchableText.contains(searchTerm);
    }).toList(growable: false);

    final pageCount = filteredItems.isEmpty
        ? 1
        : ((filteredItems.length - 1) ~/ pageSize) + 1;
    final safePageIndex = pageIndex.clamp(0, pageCount - 1);
    final start = filteredItems.isEmpty ? 0 : safePageIndex * pageSize;
    final end = filteredItems.isEmpty
        ? 0
        : (start + pageSize).clamp(0, filteredItems.length);
    final visibleItems = filteredItems.sublist(start, end);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hotel performance',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: searchController,
          onChanged: onSearchChanged,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded),
            hintText: 'Search by hotel name or code',
            suffixIcon: searchTerm.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      searchController.clear();
                      onSearchChanged('');
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: Text(
                filteredItems.isEmpty
                    ? 'No matching hotels'
                    : 'Showing ${start + 1}-$end of ${filteredItems.length}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            Text(
              'Page ${safePageIndex + 1} of $pageCount',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (visibleItems.isEmpty)
          const _EmptyAdminCard(message: 'No hotels match your search.')
        else
          for (final item in visibleItems)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _FinanceHotelCard(item: item),
            ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: safePageIndex == 0
                    ? null
                    : () => onPageChanged(safePageIndex - 1, pageCount),
                icon: const Icon(Icons.chevron_left_rounded),
                label: const Text('Previous'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: FilledButton.icon(
                onPressed: safePageIndex >= pageCount - 1
                    ? null
                    : () => onPageChanged(safePageIndex + 1, pageCount),
                icon: const Icon(Icons.chevron_right_rounded),
                label: const Text('Next'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FinanceHotelCard extends StatelessWidget {
  const _FinanceHotelCard({required this.item});
  final AdminFinanceSummary item;
  @override
  Widget build(BuildContext context) {
    final displayName = _readableHotelName(item.hotelName);
    final commissionRate = item.grossBookingRevenue <= 0
        ? 0.0
        : (item.platformCommission / item.grossBookingRevenue).clamp(0.0, 1.0);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: () => _showFinanceHotelDetails(context, item),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              LinearProgressIndicator(
                value: commissionRate,
                minHeight: 8,
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              const SizedBox(height: AppSpacing.md),
              _MetricRow(
                label: 'Booking revenue',
                value: AppFormatters.money(item.grossBookingRevenue),
              ),
              _MetricRow(
                label: 'Platform commission',
                value: AppFormatters.money(item.platformCommission),
              ),
              _MetricRow(
                label: 'Hotel payout',
                value: AppFormatters.money(item.hotelNetReceivable),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Tap to view financial details',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

void _showFinanceHotelDetails(
  BuildContext context,
  AdminFinanceSummary item,
) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final commissionRate = item.grossBookingRevenue <= 0
          ? 0.0
          : item.platformCommission / item.grossBookingRevenue;

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _readableHotelName(item.hotelName),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text('Hotel code ${_shortHotelCode(item.hotelId)}'),
              const SizedBox(height: AppSpacing.xl),
              _MetricRow(
                label: 'Successful bookings',
                value: item.successfulBookingCount.toString(),
              ),
              _MetricRow(
                label: 'Total customer payments',
                value: AppFormatters.money(item.grossBookingRevenue),
              ),
              _MetricRow(
                label: 'Platform commission',
                value: AppFormatters.money(item.platformCommission),
              ),
              _MetricRow(
                label: 'Commission rate',
                value: '${(commissionRate * 100).toStringAsFixed(1)}%',
              ),
              _MetricRow(
                label: 'Amount payable to hotel',
                value: AppFormatters.money(item.hotelNetReceivable),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'This card summarizes confirmed bookings for one hotel. '
                'Use it to compare revenue, platform fee, and the amount owed to the property.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    },
  );
}

String _readableHotelName(String value) {
  final trimmed = value.trim();
  final cleaned = trimmed.replaceFirst(
    RegExp(r'\s+[0-9a-fA-F]{24,}$'),
    '',
  );
  return cleaned.isEmpty ? 'Unnamed hotel' : cleaned;
}

String _shortHotelCode(String value) {
  final normalized = value.replaceAll('-', '').toUpperCase();
  if (normalized.length < 6) {
    return normalized.isEmpty ? 'N/A' : normalized;
  }

  return 'HM-${normalized.substring(normalized.length - 6)}';
}

class _AdminShimmerGrid extends StatelessWidget {
  const _AdminShimmerGrid();
  @override
  Widget build(BuildContext context) {
    return const AppShimmer(
      child: Column(
        children: [
          ShimmerBlock(width: double.infinity, height: 130, borderRadius: 12),
          SizedBox(height: AppSpacing.md),
          ShimmerBlock(width: double.infinity, height: 130, borderRadius: 12),
          SizedBox(height: AppSpacing.md),
          ShimmerBlock(width: double.infinity, height: 130, borderRadius: 12),
        ],
      ),
    );
  }
}

class _PaddedShimmer extends StatelessWidget {
  const _PaddedShimmer();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.xl),
      child: _AdminShimmerGrid(),
    );
  }
}

class _AdminErrorCard extends ConsumerWidget {
  const _AdminErrorCard({
    required this.message,
    required this.error,
    required this.onRetry,
  });

  final String message;
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUnauthorized = _isUnauthorized(error);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              children: [
                Icon(
                  isUnauthorized
                      ? Icons.lock_outline_rounded
                      : Icons.cloud_off_rounded,
                  color: isUnauthorized ? AppColors.warning : AppColors.danger,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  AppErrorPresenter.friendlyMessage(error),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
                if (isUnauthorized) ...[
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        ref.read(authControllerProvider.notifier).logout();
                      },
                      icon: const Icon(Icons.login_rounded),
                      label: const Text('Sign in again'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

bool _isUnauthorized(Object error) {
  if (error is UnauthorizedApiException) {
    return true;
  }

  if (error is DioException && error.error is UnauthorizedApiException) {
    return true;
  }

  return false;
}

class _EmptyAdminCard extends StatelessWidget {
  const _EmptyAdminCard({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Center(child: Text(message)),
      ),
    );
  }
}

Future<String?> _showTextDialog({
  required BuildContext context,
  required String title,
  required String label,
}) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Submit'),
          ),
        ],
      );
    },
  );
}
