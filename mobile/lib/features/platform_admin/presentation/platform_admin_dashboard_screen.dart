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
import '../../../shared/widgets/app_text_form_field.dart';
import '../application/platform_admin_providers.dart';
import '../domain/platform_admin_models.dart';

class PlatformAdminDashboardScreen extends ConsumerWidget {
  const PlatformAdminDashboardScreen({super.key});

  static const String routeName = 'platform-admin';
  static const String routePath = '/platform-admin';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Platform Admin'),
          actions: [
            IconButton(
              tooltip: 'Sign out',
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).logout(),
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(icon: Icon(Icons.analytics_rounded), text: 'Analytics'),
              Tab(icon: Icon(Icons.people_alt_rounded), text: 'Users'),
              Tab(
                icon: Icon(Icons.domain_verification_rounded),
                text: 'Hotels',
              ),
              Tab(
                icon: Icon(Icons.account_balance_wallet_rounded),
                text: 'Reconciliation',
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
              _UsersTab(),
              _HotelReviewTab(),
              _ReconciliationTab(),
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

class _UsersTab extends ConsumerStatefulWidget {
  const _UsersTab();

  @override
  ConsumerState<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends ConsumerState<_UsersTab> {
  static const int _pageSize = 8;
  static const List<String> _roles = [
    'Customer',
    'PropertyOwner',
    'HotelManager',
    'Receptionist',
    'HousekeepingStaff',
    'MaintenanceStaff',
    'PlatformAdministrator',
  ];

  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';
  String? _selectedRole;
  String? _selectedStatus;
  int _pageIndex = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _setRole(String? role) {
    setState(() {
      _selectedRole = role;
      _pageIndex = 0;
    });
  }

  void _setSearchTerm(String value) {
    setState(() {
      _searchTerm = value.trim();
      _pageIndex = 0;
    });
  }

  void _setStatus(String? status) {
    setState(() {
      _selectedStatus = status;
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
    final query = AdminUsersQuery(
      role: _selectedRole,
      searchTerm: _searchTerm,
    );
    final users = ref.watch(adminUsersProvider(query));

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(adminUsersProvider(query)),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          Text(
            'User management',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Review accounts, ban or unban users, and inspect per-user activity history.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xl),
          AppTextFormField(
            controller: _searchController,
            labelText: 'Search users',
            hintText: 'Email, name, or phone',
            prefixIcon: const Icon(Icons.search_rounded),
            textInputAction: TextInputAction.search,
            onFieldSubmitted: _setSearchTerm,
          ),
          const SizedBox(height: AppSpacing.md),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: ChoiceChip(
                    label: const Text('All'),
                    selected: _selectedRole == null,
                    onSelected: (_) => _setRole(null),
                  ),
                ),
                for (final role in _roles)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ChoiceChip(
                      label: Text(_shortRoleLabel(role)),
                      selected: _selectedRole == role,
                      onSelected: (_) => _setRole(role),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: ChoiceChip(
                    label: const Text('All status'),
                    selected: _selectedStatus == null,
                    onSelected: (_) => _setStatus(null),
                  ),
                ),
                for (final status in const ['Active', 'Suspended', 'Inactive'])
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ChoiceChip(
                      label: Text(status),
                      selected: _selectedStatus == status,
                      onSelected: (_) => _setStatus(status),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          users.when(
            data: (items) {
              final visibleItems = _selectedStatus == null
                  ? items
                  : items
                      .where((user) => user.status == _selectedStatus)
                      .toList(growable: false);
              return Column(
                children: [
                  _UserRoleSummary(users: visibleItems),
                  const SizedBox(height: AppSpacing.xl),
                  _AdminUserPagedList(
                    users: visibleItems,
                    pageIndex: _pageIndex,
                    pageSize: _pageSize,
                    onPageChanged: _goToPage,
                    onUserChanged: () =>
                        ref.invalidate(adminUsersProvider(query)),
                  ),
                ],
              );
            },
            error: (error, stackTrace) => _AdminErrorCard(
              message: 'Unable to load users.',
              error: error,
              onRetry: () => ref.invalidate(adminUsersProvider(query)),
            ),
            loading: () => const _PaddedShimmer(),
          ),
        ],
      ),
    );
  }
}

class _UserRoleSummary extends StatelessWidget {
  const _UserRoleSummary({required this.users});

  final List<AdminUser> users;

  @override
  Widget build(BuildContext context) {
    final customers =
        users.where((user) => user.roles.contains('Customer')).length;
    final owners =
        users.where((user) => user.roles.contains('PropertyOwner')).length;
    final staff = users.where((user) {
      return user.roles.any((role) {
        return role == 'HotelManager' ||
            role == 'Receptionist' ||
            role == 'HousekeepingStaff' ||
            role == 'MaintenanceStaff';
      });
    }).length;
    final admins = users
        .where((user) => user.roles.contains('PlatformAdministrator'))
        .length;

    return _KpiGrid(
      cards: [
        _KpiData(
          'Customers',
          customers.toString(),
          'Guest accounts',
          Icons.person_rounded,
        ),
        _KpiData(
          'Owners',
          owners.toString(),
          'Property partners',
          Icons.business_rounded,
        ),
        _KpiData(
          'Hotel staff',
          staff.toString(),
          'Operational users',
          Icons.badge_rounded,
        ),
        _KpiData(
          'Admins',
          admins.toString(),
          'Platform operators',
          Icons.admin_panel_settings_rounded,
        ),
      ],
    );
  }
}

class _AdminUserPagedList extends StatelessWidget {
  const _AdminUserPagedList({
    required this.users,
    required this.pageIndex,
    required this.pageSize,
    required this.onPageChanged,
    required this.onUserChanged,
  });

  final List<AdminUser> users;
  final int pageIndex;
  final int pageSize;
  final void Function(int pageIndex, int pageCount) onPageChanged;
  final VoidCallback onUserChanged;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return const _EmptyAdminCard(
        message: 'No users match the current filter.',
      );
    }

    final pageCount = ((users.length - 1) ~/ pageSize) + 1;
    final safePageIndex = pageIndex.clamp(0, pageCount - 1);
    final start = safePageIndex * pageSize;
    final end = (start + pageSize).clamp(0, users.length);
    final visibleUsers = users.sublist(start, end);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Showing ${start + 1}-$end of ${users.length} users',
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
        for (final user in visibleUsers)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _AdminUserCard(
              user: user,
              onUserChanged: onUserChanged,
            ),
          ),
        _AdminPaginationControls(
          currentPageIndex: safePageIndex,
          pageCount: pageCount,
          onPageChanged: onPageChanged,
        ),
      ],
    );
  }
}

class _AdminUserCard extends StatelessWidget {
  const _AdminUserCard({
    required this.user,
    required this.onUserChanged,
  });

  final AdminUser user;
  final VoidCallback onUserChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: () => _showUserDetails(context, user, onUserChanged),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                    child: Text(_initials(user.fullName, user.email)),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.fullName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(user.email),
                      ],
                    ),
                  ),
                  _StatusBadge(label: user.status),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final role in user.roles)
                    Chip(label: Text(_shortRoleLabel(role))),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                user.hotelIds.isEmpty
                    ? 'No hotel scope'
                    : '${user.hotelIds.length} assigned hotel${user.hotelIds.length == 1 ? '' : 's'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _showUserDetails(context, user, onUserChanged),
                      icon: const Icon(Icons.history_rounded),
                      label: const Text('Activity history'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () =>
                          _showUserDetails(context, user, onUserChanged),
                      icon: const Icon(Icons.manage_accounts_rounded),
                      label: const Text('Manage'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminPaginationControls extends StatefulWidget {
  const _AdminPaginationControls({
    required this.currentPageIndex,
    required this.pageCount,
    required this.onPageChanged,
  });

  final int currentPageIndex;
  final int pageCount;
  final void Function(int pageIndex, int pageCount) onPageChanged;

  @override
  State<_AdminPaginationControls> createState() =>
      _AdminPaginationControlsState();
}

class _AdminPaginationControlsState extends State<_AdminPaginationControls> {
  late final TextEditingController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController =
        TextEditingController(text: (widget.currentPageIndex + 1).toString());
  }

  @override
  void didUpdateWidget(covariant _AdminPaginationControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextText = (widget.currentPageIndex + 1).toString();
    if (_pageController.text != nextText) {
      _pageController.text = nextText;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _jumpToPage() {
    final pageNumber = int.tryParse(_pageController.text.trim());
    if (pageNumber == null) {
      return;
    }

    widget.onPageChanged(pageNumber - 1, widget.pageCount);
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            Row(
              children: [
                Flexible(
                  child: OutlinedButton(
                    onPressed: widget.currentPageIndex == 0
                        ? null
                        : () => widget.onPageChanged(
                              widget.currentPageIndex - 1,
                              widget.pageCount,
                            ),
                    child: const Icon(Icons.chevron_left_rounded),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(
                  width: 92,
                  child: AppTextFormField(
                    controller: _pageController,
                    labelText: 'Page',
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _jumpToPage(),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: FilledButton(
                    onPressed: widget.currentPageIndex >= widget.pageCount - 1
                        ? null
                        : () => widget.onPageChanged(
                              widget.currentPageIndex + 1,
                              widget.pageCount,
                            ),
                    child: const Icon(Icons.chevron_right_rounded),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Page ${widget.currentPageIndex + 1} of ${widget.pageCount}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminPagedCards<T> extends StatelessWidget {
  const _AdminPagedCards({
    required this.items,
    required this.itemLabel,
    required this.emptyMessage,
    required this.pageIndex,
    required this.pageSize,
    required this.onPageChanged,
    required this.itemBuilder,
  });

  final List<T> items;
  final String itemLabel;
  final String emptyMessage;
  final int pageIndex;
  final int pageSize;
  final void Function(int pageIndex, int pageCount) onPageChanged;
  final Widget Function(T item) itemBuilder;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _EmptyAdminCard(message: emptyMessage);
    }

    final pageCount = ((items.length - 1) ~/ pageSize) + 1;
    final safePageIndex = pageIndex.clamp(0, pageCount - 1);
    final start = safePageIndex * pageSize;
    final end = (start + pageSize).clamp(0, items.length);
    final visibleItems = items.sublist(start, end);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Showing ${start + 1}-$end of ${items.length} $itemLabel',
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
        for (final item in visibleItems)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: itemBuilder(item),
          ),
        _AdminPaginationControls(
          currentPageIndex: safePageIndex,
          pageCount: pageCount,
          onPageChanged: onPageChanged,
        ),
      ],
    );
  }
}

class _HotelReviewTab extends ConsumerStatefulWidget {
  const _HotelReviewTab();

  @override
  ConsumerState<_HotelReviewTab> createState() => _HotelReviewTabState();
}

class _HotelReviewTabState extends ConsumerState<_HotelReviewTab> {
  static const int _pageSize = 5;

  int _pageIndex = 0;

  void _goToPage(int pageIndex, int pageCount) {
    setState(() {
      _pageIndex = pageIndex.clamp(0, pageCount - 1);
    });
  }

  @override
  Widget build(BuildContext context) {
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
            _AdminPagedCards<AdminHotel>(
              items: items,
              itemLabel: 'hotels',
              emptyMessage: 'No hotels are waiting for review.',
              pageIndex: _pageIndex,
              pageSize: _pageSize,
              onPageChanged: _goToPage,
              itemBuilder: (hotel) => _HotelReviewCard(hotel: hotel),
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

class _ReconciliationTab extends ConsumerWidget {
  const _ReconciliationTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payments = ref.watch(unreconciledPaymentsProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(unreconciledPaymentsProvider),
      child: payments.when(
        loading: () => const _PaddedShimmer(),
        error: (error, _) => _AdminErrorCard(
          message: 'Unable to load payment reconciliation.',
          error: error,
          onRetry: () => ref.invalidate(unreconciledPaymentsProvider),
        ),
        data: (items) => items.isEmpty
            ? ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: const [
                  _EmptyAdminCard(
                    message:
                        'No payments are waiting for review. Paid Demo transactions appear here before settlement.',
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: items.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) =>
                    _PaymentTransactionCard(item: items[index]),
              ),
      ),
    );
  }
}

class _PaymentTransactionCard extends ConsumerStatefulWidget {
  const _PaymentTransactionCard({required this.item});

  final AdminPaymentTransaction item;

  @override
  ConsumerState<_PaymentTransactionCard> createState() =>
      _PaymentTransactionCardState();
}

class _PaymentTransactionCardState
    extends ConsumerState<_PaymentTransactionCard> {
  bool _loading = false;

  Future<void> _review(String status) async {
    final noteController = TextEditingController();
    final exception = status == 'Exception';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          exception
              ? 'Flag reconciliation exception'
              : 'Confirm reconciliation',
        ),
        content: TextField(
          controller: noteController,
          maxLength: 1000,
          decoration: InputDecoration(
            labelText:
                exception ? 'Exception reason' : 'Review note (optional)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (exception && noteController.text.trim().isEmpty) {
                return;
              }
              Navigator.of(context).pop(true);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    final note = noteController.text.trim();
    noteController.dispose();
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _loading = true);
    try {
      await ref.read(platformAdminApiProvider).updatePaymentReconciliation(
            paymentTransactionId: widget.item.id,
            status: status,
            note: note,
          );
      ref.invalidate(unreconciledPaymentsProvider);
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.hotelName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(AppFormatters.money(item.amount)),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text('${item.provider} payment · ${item.status}'),
            Text('Reference: ${item.gatewayReference ?? 'Not recorded'}'),
            Text(
              'Booking: ${item.bookingId.length >= 8 ? item.bookingId.substring(0, 8).toUpperCase() : item.bookingId}',
            ),
            const SizedBox(height: AppSpacing.md),
            if (_loading)
              const LinearProgressIndicator()
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _review('Exception'),
                      icon: const Icon(Icons.report_problem_outlined),
                      label: const Text('Exception'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _review('Reconciled'),
                      icon: const Icon(Icons.fact_check_outlined),
                      label: const Text('Reconcile'),
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

class _SettlementsTab extends ConsumerStatefulWidget {
  const _SettlementsTab();

  @override
  ConsumerState<_SettlementsTab> createState() => _SettlementsTabState();
}

class _SettlementsTabState extends ConsumerState<_SettlementsTab> {
  static const int _pageSize = 5;

  int _pageIndex = 0;
  bool _creating = false;

  void _goToPage(int pageIndex, int pageCount) {
    setState(() {
      _pageIndex = pageIndex.clamp(0, pageCount - 1);
    });
  }

  Future<void> _createSettlement() async {
    final hotels = ref.read(adminFinanceSummaryProvider).asData?.value ??
        const <AdminFinanceSummary>[];
    if (hotels.isEmpty) {
      await AppErrorPresenter.showBottomSheet(
        context,
        StateError('No hotel finance records are available.'),
      );
      return;
    }

    final today = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(today.year - 2),
      lastDate: today,
      initialDateRange: DateTimeRange(
        start: today.subtract(const Duration(days: 30)),
        end: today,
      ),
    );
    if (range == null || !mounted) {
      return;
    }

    String hotelId = hotels.first.hotelId;
    String paymentMode = 'PlatformCollect';
    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create finance batch'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: hotelId,
                decoration: const InputDecoration(labelText: 'Hotel'),
                items: hotels
                    .map(
                      (hotel) => DropdownMenuItem(
                        value: hotel.hotelId,
                        child: Text(hotel.hotelName),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) => setDialogState(() => hotelId = value!),
              ),
              DropdownButtonFormField<String>(
                initialValue: paymentMode,
                decoration:
                    const InputDecoration(labelText: 'Finance batch type'),
                items: const [
                  DropdownMenuItem(
                    value: 'PlatformCollect',
                    child: Text('Hotel payout'),
                  ),
                  DropdownMenuItem(
                    value: 'PayAtProperty',
                    child: Text('Commission collection'),
                  ),
                ],
                onChanged: (value) =>
                    setDialogState(() => paymentMode = value!),
              ),
              TextField(
                controller: noteController,
                maxLength: 1000,
                decoration:
                    const InputDecoration(labelText: 'Batch note (optional)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    final note = noteController.text.trim();
    noteController.dispose();
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _creating = true);
    try {
      await ref.read(platformAdminApiProvider).createSettlement(
            hotelId: hotelId,
            paymentMode: paymentMode,
            fromDate: range.start,
            toDate: range.end,
            adminNote: note,
          );
      ref.invalidate(settlementsProvider);
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

  @override
  Widget build(BuildContext context) {
    final settlements = ref.watch(settlementsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(settlementsProvider),
      child: settlements.when(
        data: (items) => ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Settlements',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                FilledButton.icon(
                  onPressed: _creating ? null : _createSettlement,
                  icon: _creating
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_rounded),
                  label: const Text('Create'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Hotel payouts use reconciled Demo payments after refunds. Commission collections track what Pay-at-Property hotels owe the platform.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xl),
            _AdminPagedCards<AdminSettlement>(
              items: items,
              itemLabel: 'settlements',
              emptyMessage: 'No settlement records found.',
              pageIndex: _pageIndex,
              pageSize: _pageSize,
              onPageChanged: _goToPage,
              itemBuilder: (item) => _SettlementCard(item: item),
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

class _RefundsTab extends ConsumerStatefulWidget {
  const _RefundsTab();

  @override
  ConsumerState<_RefundsTab> createState() => _RefundsTabState();
}

class _RefundsTabState extends ConsumerState<_RefundsTab> {
  static const int _pageSize = 5;

  int _pageIndex = 0;

  void _goToPage(int pageIndex, int pageCount) {
    setState(() {
      _pageIndex = pageIndex.clamp(0, pageCount - 1);
    });
  }

  @override
  Widget build(BuildContext context) {
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
            _AdminPagedCards<AdminRefund>(
              items: items,
              itemLabel: 'refunds',
              emptyMessage: 'No refund requests are pending.',
              pageIndex: _pageIndex,
              pageSize: _pageSize,
              onPageChanged: _goToPage,
              itemBuilder: (item) => _RefundCard(item: item),
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
  Future<void> _setStatus(
    String status, {
    required String reference,
    required String note,
  }) async {
    setState(() => _loading = true);
    try {
      await ref.read(platformAdminApiProvider).updateSettlementStatus(
            settlementId: widget.item.id,
            status: status,
            settledAmount:
                status == 'Settled' ? widget.item.expectedAmount : null,
            settlementDateUtc:
                status == 'Settled' ? DateTime.now().toUtc() : null,
            reference: status == 'Settled' ? reference : null,
            adminNote: note,
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

  Future<void> _showAction(String status) async {
    final referenceController = TextEditingController(
      text: 'SET-${widget.item.id.replaceAll('-', '').toUpperCase()}',
    );
    final noteController = TextEditingController();
    final isException = status == 'Exception';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isException ? 'Record finance exception' : 'Finalize settlement',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isException)
              TextField(
                controller: referenceController,
                decoration: const InputDecoration(
                  labelText: 'Bank or collection reference',
                ),
              ),
            TextField(
              controller: noteController,
              maxLength: 1000,
              decoration: InputDecoration(
                labelText:
                    isException ? 'Exception reason' : 'Admin note (optional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if ((isException && noteController.text.trim().isEmpty) ||
                  (!isException && referenceController.text.trim().isEmpty)) {
                return;
              }
              Navigator.of(context).pop(true);
            },
            child: Text(isException ? 'Record exception' : 'Confirm'),
          ),
        ],
      ),
    );
    final reference = referenceController.text.trim();
    final note = noteController.text.trim();
    referenceController.dispose();
    noteController.dispose();
    if (confirmed == true && mounted) {
      await _setStatus(status, reference: reference, note: note);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isPending = item.status == 'Pending';
    final typeLabel = item.settlementType == 'HotelPayable'
        ? 'Hotel payout'
        : 'Platform commission collection';
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
              '$typeLabel · ${item.status} · ${item.items.length} items',
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              AppFormatters.money(item.totalAmount),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Text('Expected amount from immutable booking evidence'),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('View calculation evidence'),
              children: item.items
                  .map(
                    (evidence) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${evidence.paymentMode} · ${evidence.bookingStatus}',
                          ),
                          Text(
                            'Gross ${AppFormatters.money(evidence.grossAmount)} · Refund ${AppFormatters.money(evidence.refundAmount)} · Commission ${AppFormatters.money(evidence.commissionAmount)}',
                          ),
                          Text(
                            'Eligible amount ${AppFormatters.money(evidence.amount)}',
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
            if (item.reference.isNotEmpty) Text('Reference: ${item.reference}'),
            const SizedBox(height: AppSpacing.lg),
            if (_loading)
              const LinearProgressIndicator()
            else if (!isPending)
              _ProcessedSettlementBanner(status: item.status)
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showAction('Exception'),
                      icon: const Icon(Icons.report_problem_outlined),
                      label: const Text('Exception'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _showAction('Settled'),
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: const Text('Mark settled'),
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

class _ProcessedSettlementBanner extends StatelessWidget {
  const _ProcessedSettlementBanner({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final isSettled = status == 'Settled' || status == 'Collected';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isSettled ? AppColors.successSoft : AppColors.warningSoft,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        children: [
          Icon(
            isSettled
                ? Icons.check_circle_outline_rounded
                : Icons.report_problem_outlined,
            color: isSettled ? AppColors.success : AppColors.warning,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              isSettled
                  ? 'This settlement has already been marked as settled.'
                  : 'This settlement is in exception status and needs review.',
            ),
          ),
        ],
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
        _AdminPaginationControls(
          currentPageIndex: safePageIndex,
          pageCount: pageCount,
          onPageChanged: onPageChanged,
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isActive = label == 'Active';
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: isActive ? AppColors.successSoft : AppColors.warningSoft,
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

void _showUserDetails(
  BuildContext context,
  AdminUser user,
  VoidCallback onUserChanged,
) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
    ),
    builder: (context) {
      return Consumer(
        builder: (context, ref, child) {
          final activity = ref.watch(adminUserActivityProvider(user.id));
          final isSuspended = user.status == 'Suspended';

          Future<void> updateStatus() async {
            try {
              if (isSuspended) {
                await ref
                    .read(platformAdminApiProvider)
                    .reactivateUser(user.id);
              } else {
                await ref.read(platformAdminApiProvider).suspendUser(user.id);
              }

              ref.invalidate(adminUserActivityProvider(user.id));
              onUserChanged();
              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      content: Text(
                        isSuspended
                            ? 'User account was unbanned.'
                            : 'User account was banned.',
                      ),
                    ),
                  );
              }
            } catch (error) {
              if (context.mounted) {
                await AppErrorPresenter.showBottomSheet(context, error);
              }
            }
          }

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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.brand,
                        foregroundColor: Colors.white,
                        child: Text(_initials(user.fullName, user.email)),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.fullName,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(user.email),
                          ],
                        ),
                      ),
                      _StatusBadge(label: user.status),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _MetricRow(
                    label: 'Phone',
                    value: user.phoneNumber ?? 'Not set',
                  ),
                  _MetricRow(
                    label: 'Created',
                    value: AppFormatters.displayDate(user.createdAtUtc),
                  ),
                  _MetricRow(
                    label: 'Roles',
                    value: user.roles.map(_shortRoleLabel).join(', '),
                  ),
                  _MetricRow(
                    label: 'Hotel assignments',
                    value: user.hotelIds.isEmpty
                        ? 'None'
                        : '${user.hotelIds.length} hotel${user.hotelIds.length == 1 ? '' : 's'}',
                  ),
                  if (user.hotelIds.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Hotel scopes',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    for (final hotelId in user.hotelIds)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: Text(_shortHotelCode(hotelId)),
                      ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: updateStatus,
                          icon: Icon(
                            isSuspended
                                ? Icons.lock_open_rounded
                                : Icons.block_rounded,
                          ),
                          label: Text(isSuspended ? 'Unban user' : 'Ban user'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Close'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Activity history',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  activity.when(
                    data: (items) {
                      if (items.isEmpty) {
                        return const Text(
                          'No activity records yet. Ban, unban, approval, or finance actions will appear here after they are recorded.',
                        );
                      }

                      final visibleItems =
                          items.take(8).toList(growable: false);
                      return Column(
                        children: [
                          for (final item in visibleItems)
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.history_rounded),
                              title: Text(item.actionType),
                              subtitle: Text(item.summary),
                              trailing: Text(
                                AppFormatters.displayDate(
                                  item.actionTimestampUtc,
                                ),
                              ),
                            ),
                          if (items.length > visibleItems.length)
                            Text(
                              'Showing latest ${visibleItems.length} of ${items.length} records.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      );
                    },
                    error: (error, stackTrace) => Text(
                      AppErrorPresenter.friendlyMessage(error),
                    ),
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                      child: LinearProgressIndicator(),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
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

String _shortRoleLabel(String role) {
  return switch (role) {
    'PropertyOwner' => 'Owner',
    'HotelManager' => 'Manager',
    'HousekeepingStaff' => 'Housekeeping',
    'MaintenanceStaff' => 'Maintenance',
    'PlatformAdministrator' => 'Admin',
    _ => role,
  };
}

String _initials(String fullName, String email) {
  final nameParts = fullName
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (nameParts.length >= 2) {
    return '${nameParts.first[0]}${nameParts.last[0]}'.toUpperCase();
  }

  if (nameParts.length == 1 && nameParts.first.isNotEmpty) {
    return nameParts.first[0].toUpperCase();
  }

  return email.isEmpty ? '?' : email[0].toUpperCase();
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
