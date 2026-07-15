import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../features/auth/application/auth_controller.dart';
import '../../../features/auth/domain/auth_models.dart';
import '../../../features/operations/presentation/operations_dashboard_screen.dart';
import '../../../features/platform_admin/presentation/platform_admin_dashboard_screen.dart';
import '../../../shared/utils/app_formatters.dart';
import '../../../shared/widgets/app_error_presenter.dart';
import '../application/marketplace_providers.dart';
import '../domain/marketplace_models.dart';
import 'hotel_detail_screen.dart';
import 'widgets/hotel_card.dart';
import 'widgets/marketplace_skeletons.dart';
import 'widgets/quantity_stepper.dart';

class MarketplaceScreen extends ConsumerStatefulWidget {
  const MarketplaceScreen({super.key});

  static const String routeName = 'marketplace';
  static const String routePath = '/marketplace';

  @override
  ConsumerState<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends ConsumerState<MarketplaceScreen> {
  late final TextEditingController _locationController;

  @override
  void initState() {
    super.initState();
    _locationController = TextEditingController(
      text: ref.read(hotelSearchQueryProvider).location,
    );
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange(HotelSearchQuery query) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(
        start: query.checkInDate,
        end: query.checkOutDate,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            datePickerTheme: DatePickerThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.lg),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) {
      return;
    }

    ref.read(hotelSearchQueryProvider.notifier).state = query.copyWith(
      checkInDate: picked.start,
      checkOutDate: picked.end,
    );
  }

  void _applySearch(HotelSearchQuery query) {
    FocusScope.of(context).unfocus();
    ref.read(hotelSearchQueryProvider.notifier).state = query.copyWith(
      location: _locationController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(hotelSearchQueryProvider);
    final results = ref.watch(hotelSearchResultsProvider(query));
    final session = ref.watch(authControllerProvider).userSession;
    final roles = session?.roles ?? const [];
    final canOpenOperations = (session?.hotelIds.isNotEmpty ?? false) &&
        roles.any((role) {
          return role == UserRoleCode.propertyOwner.apiValue ||
              role == UserRoleCode.hotelManager.apiValue ||
              role == UserRoleCode.receptionist.apiValue ||
              role == UserRoleCode.housekeepingStaff.apiValue ||
              role == UserRoleCode.maintenanceStaff.apiValue ||
              role == UserRoleCode.platformAdministrator.apiValue;
        });
    final canOpenPlatformAdmin =
        roles.contains(UserRoleCode.platformAdministrator.apiValue);

    ref.listen(hotelSearchResultsProvider(query), (previous, next) {
      next.whenOrNull(
        error: (error, stackTrace) {
          AppErrorPresenter.showSnackBar(context, error);
        },
      );
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find stays'),
        actions: [
          if (canOpenOperations)
            IconButton(
              tooltip: 'Hotel operations',
              onPressed: () {
                context.go(OperationsDashboardScreen.routePath);
              },
              icon: const Icon(Icons.dashboard_customize_rounded),
            ),
          if (canOpenPlatformAdmin)
            IconButton(
              tooltip: 'Platform admin',
              onPressed: () {
                context.go(PlatformAdminDashboardScreen.routePath);
              },
              icon: const Icon(Icons.admin_panel_settings_rounded),
            ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () {
              ref.read(authControllerProvider.notifier).logout();
            },
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(hotelSearchResultsProvider(query));
          },
          child: ListView(
            key: const PageStorageKey<String>('marketplace-search-list'),
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              _SearchPanel(
                query: query,
                locationController: _locationController,
                onPickDates: () => _pickDateRange(query),
                onApplySearch: () => _applySearch(query),
                onGuestChanged: (value) {
                  ref.read(hotelSearchQueryProvider.notifier).state =
                      query.copyWith(guestCount: value);
                },
                onRoomChanged: (value) {
                  ref.read(hotelSearchQueryProvider.notifier).state =
                      query.copyWith(roomCount: value);
                },
              ),
              const SizedBox(height: AppSpacing.xl),
              results.when(
                data: (hotels) {
                  if (hotels.isEmpty) {
                    return const _EmptySearchResult();
                  }

                  return Column(
                    children: [
                      for (var index = 0; index < hotels.length; index += 1)
                        Padding(
                          padding: EdgeInsets.only(
                            bottom:
                                index == hotels.length - 1 ? 0 : AppSpacing.md,
                          ),
                          child: HotelCard(
                            hotel: hotels[index],
                            onTap: () {
                              context.go(
                                HotelDetailScreen.pathFor(hotels[index].id),
                                extra: query,
                              );
                            },
                          ),
                        ),
                    ],
                  );
                },
                error: (error, stackTrace) => _ErrorPanel(
                  onRetry: () {
                    ref.invalidate(hotelSearchResultsProvider(query));
                  },
                ),
                loading: () => const HotelCardSkeletonList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchPanel extends StatelessWidget {
  const _SearchPanel({
    required this.query,
    required this.locationController,
    required this.onPickDates,
    required this.onApplySearch,
    required this.onGuestChanged,
    required this.onRoomChanged,
  });

  final HotelSearchQuery query;
  final TextEditingController locationController;
  final VoidCallback onPickDates;
  final VoidCallback onApplySearch;
  final ValueChanged<int> onGuestChanged;
  final ValueChanged<int> onRoomChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Where to next?', style: textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Search approved hotels with live room availability.',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xl),
            TextField(
              controller: locationController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => onApplySearch(),
              decoration: const InputDecoration(
                labelText: 'Destination',
                hintText: 'City or area',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: onPickDates,
              icon: const Icon(Icons.calendar_month_rounded),
              label: Text(
                '${AppFormatters.displayDate(query.checkInDate)} - ${AppFormatters.displayDate(query.checkOutDate)}',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            QuantityStepper(
              label: 'Guests',
              value: query.guestCount,
              minimum: 1,
              maximum: 30,
              onChanged: onGuestChanged,
            ),
            const SizedBox(height: AppSpacing.md),
            QuantityStepper(
              label: 'Rooms',
              value: query.roomCount,
              minimum: 1,
              maximum: 10,
              onChanged: onRoomChanged,
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: onApplySearch,
              icon: const Icon(Icons.travel_explore_rounded),
              label: const Text('Search hotels'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySearchResult extends StatelessWidget {
  const _EmptySearchResult();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(AppRadii.lg),
              ),
              child: const Icon(Icons.hotel_class_outlined),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No stays found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Try another city, date range, or reduce the number of rooms.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: AppColors.danger,
              size: 34,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Unable to load hotels',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
