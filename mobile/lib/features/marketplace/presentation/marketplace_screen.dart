import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../features/auth/application/auth_controller.dart';
import '../../../features/auth/domain/auth_models.dart';
import '../../../features/auth/presentation/login_screen.dart';
import '../../../features/customer/application/customer_state.dart';
import '../../../features/operations/presentation/operations_dashboard_screen.dart';
import '../../../features/platform_admin/presentation/platform_admin_dashboard_screen.dart';
import '../../../shared/utils/app_formatters.dart';
import '../../../shared/widgets/app_error_presenter.dart';
import '../../../shared/widgets/app_text_form_field.dart';
import '../application/marketplace_providers.dart';
import '../domain/marketplace_models.dart';
import 'hotel_detail_screen.dart';
import 'widgets/hotel_card.dart';
import 'widgets/marketplace_skeletons.dart';
import 'widgets/quantity_stepper.dart';

enum _HotelSortOption {
  recommended,
  priceLowToHigh,
  priceHighToLow,
  name,
}

class MarketplaceScreen extends ConsumerStatefulWidget {
  const MarketplaceScreen({
    super.key,
    this.showAppBar = true,
  });

  static const String routeName = 'marketplace';
  static const String routePath = '/marketplace';

  final bool showAppBar;

  @override
  ConsumerState<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends ConsumerState<MarketplaceScreen> {
  static const int _pageSize = 8;

  late final TextEditingController _locationController;
  late HotelSearchQuery _draftQuery;
  int _pageIndex = 0;
  String? _selectedCity;
  _HotelSortOption _sortOption = _HotelSortOption.recommended;
  bool _showSearchResults = false;

  @override
  void initState() {
    super.initState();
    _locationController = TextEditingController(
      text: ref.read(hotelSearchQueryProvider).location,
    );
    _draftQuery = ref.read(hotelSearchQueryProvider);
    _locationController.addListener(_scheduleLocationSearch);
  }

  @override
  void dispose() {
    _locationController.removeListener(_scheduleLocationSearch);
    _locationController.dispose();
    super.dispose();
  }

  void _scheduleLocationSearch() {
    final query = _draftQuery;
    if (_locationController.text.trim() == query.location.trim()) {
      return;
    }

    _updateDraftQuery(query.copyWith(location: _locationController.text));
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

    _updateDraftQuery(
      _draftQuery.copyWith(
        checkInDate: picked.start,
        checkOutDate: picked.end,
      ),
    );
  }

  void _applySearch(HotelSearchQuery query) {
    FocusScope.of(context).unfocus();
    _setSearchQuery(query.copyWith(location: _locationController.text));
    setState(() => _showSearchResults = true);
  }

  void _updateDraftQuery(HotelSearchQuery query) {
    setState(() {
      _draftQuery = query;
      _pageIndex = 0;
      _selectedCity = null;
    });
  }

  void _setSearchQuery(HotelSearchQuery query) {
    setState(() {
      _draftQuery = query;
      _pageIndex = 0;
      _selectedCity = null;
    });
    ref.read(hotelSearchQueryProvider.notifier).state = query;
  }

  void _setCityFilter(String? city) {
    setState(() {
      _selectedCity = city;
      _pageIndex = 0;
    });
  }

  void _setSortOption(_HotelSortOption sortOption) {
    setState(() {
      _sortOption = sortOption;
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
      appBar: widget.showAppBar
          ? AppBar(
              title: Text(
                _showSearchResults
                    ? 'Hotel Search Result Screen'
                    : 'Home / Search Screen',
              ),
              leading: _showSearchResults
                  ? IconButton(
                      tooltip: 'Back to search',
                      onPressed: () {
                        setState(() => _showSearchResults = false);
                      },
                      icon: const Icon(Icons.arrow_back_rounded),
                    )
                  : null,
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
                if (session == null)
                  TextButton.icon(
                    onPressed: () => context.go(LoginScreen.routePath),
                    icon: const Icon(Icons.login_rounded),
                    label: const Text('Sign in'),
                  )
                else
                  IconButton(
                    tooltip: 'Sign out',
                    onPressed: () {
                      ref.read(authControllerProvider.notifier).logout();
                    },
                    icon: const Icon(Icons.logout_rounded),
                  ),
              ],
            )
          : null,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(hotelSearchResultsProvider(query));
          },
          child: ListView(
            key: const PageStorageKey<String>('marketplace-search-list'),
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              if (!_showSearchResults)
                _SearchPanel(
                  query: _draftQuery,
                  locationController: _locationController,
                  onPickDates: () => _pickDateRange(_draftQuery),
                  onApplySearch: () => _applySearch(_draftQuery),
                  onGuestChanged: (value) {
                    _updateDraftQuery(
                      _draftQuery.copyWith(guestCount: value),
                    );
                  },
                  onRoomChanged: (value) {
                    _updateDraftQuery(
                      _draftQuery.copyWith(roomCount: value),
                    );
                  },
                )
              else ...[
                if (!widget.showAppBar)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() => _showSearchResults = false);
                      },
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Back to search'),
                    ),
                  ),
                if (!widget.showAppBar) const SizedBox(height: AppSpacing.sm),
                results.when(
                  data: (hotels) {
                    if (hotels.isEmpty) {
                      return Column(
                        children: [
                          _SearchCriteriaSummary(query: query),
                          const SizedBox(height: AppSpacing.md),
                          const _EmptySearchResult(),
                        ],
                      );
                    }

                    return Column(
                      children: [
                        _SearchCriteriaSummary(query: query),
                        const SizedBox(height: AppSpacing.md),
                        _HotelResultPagedList(
                          hotels: hotels,
                          query: query,
                          pageIndex: _pageIndex,
                          pageSize: _pageSize,
                          selectedCity: _selectedCity,
                          sortOption: _sortOption,
                          onPageChanged: _goToPage,
                          onCityChanged: _setCityFilter,
                          onSortChanged: _setSortOption,
                          onToggleSaved: (hotel) async {
                            if (session == null) {
                              context.push(LoginScreen.routePath);
                              return;
                            }
                            if (!roles
                                .contains(UserRoleCode.customer.apiValue)) {
                              AppErrorPresenter.showSnackBar(
                                context,
                                'Saved hotels are available for customer accounts.',
                              );
                              return;
                            }
                            try {
                              await ref
                                  .read(customerStateProvider.notifier)
                                  .toggleSavedHotel(hotel);
                            } catch (error) {
                              if (context.mounted) {
                                AppErrorPresenter.showSnackBar(context, error);
                              }
                            }
                          },
                          isSaved: (hotelId) {
                            return ref
                                .watch(customerStateProvider)
                                .savedHotels
                                .any((hotel) => hotel.id == hotelId);
                          },
                        ),
                      ],
                    );
                  },
                  error: (error, stackTrace) => _ErrorPanel(
                    error: error,
                    onRetry: () {
                      ref.invalidate(hotelSearchResultsProvider(query));
                    },
                  ),
                  loading: () => const HotelCardSkeletonList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HotelResultPagedList extends StatelessWidget {
  const _HotelResultPagedList({
    required this.hotels,
    required this.query,
    required this.pageIndex,
    required this.pageSize,
    required this.selectedCity,
    required this.sortOption,
    required this.onPageChanged,
    required this.onCityChanged,
    required this.onSortChanged,
    required this.onToggleSaved,
    required this.isSaved,
  });

  final List<HotelSearchResult> hotels;
  final HotelSearchQuery query;
  final int pageIndex;
  final int pageSize;
  final String? selectedCity;
  final _HotelSortOption sortOption;
  final void Function(int pageIndex, int pageCount) onPageChanged;
  final ValueChanged<String?> onCityChanged;
  final ValueChanged<_HotelSortOption> onSortChanged;
  final ValueChanged<HotelSearchResult> onToggleSaved;
  final bool Function(String hotelId) isSaved;

  @override
  Widget build(BuildContext context) {
    final cities = hotels
        .map((hotel) => hotel.city.trim())
        .where((city) => city.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final filteredHotels = hotels.where((hotel) {
      return selectedCity == null || hotel.city == selectedCity;
    }).toList(growable: false);
    final sortedHotels = _sortHotels(filteredHotels, sortOption);

    if (sortedHotels.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HotelResultControls(
            cities: cities,
            selectedCity: selectedCity,
            sortOption: sortOption,
            onCityChanged: onCityChanged,
            onSortChanged: onSortChanged,
          ),
          const SizedBox(height: AppSpacing.md),
          const _EmptySearchResult(
            message: 'No stays match this filter.',
            description: 'Choose another city or clear the current filter.',
          ),
        ],
      );
    }

    final pageCount = ((sortedHotels.length - 1) ~/ pageSize) + 1;
    final safePageIndex = pageIndex.clamp(0, pageCount - 1);
    final start = safePageIndex * pageSize;
    final end = (start + pageSize).clamp(0, sortedHotels.length);
    final visibleHotels = sortedHotels.sublist(start, end);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HotelResultControls(
          cities: cities,
          selectedCity: selectedCity,
          sortOption: sortOption,
          onCityChanged: onCityChanged,
          onSortChanged: onSortChanged,
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: Text(
                'Showing ${start + 1}-$end of ${sortedHotels.length} stays',
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
        for (var index = 0; index < visibleHotels.length; index += 1)
          Padding(
            padding: EdgeInsets.only(
              bottom: index == visibleHotels.length - 1
                  ? AppSpacing.lg
                  : AppSpacing.md,
            ),
            child: HotelCard(
              hotel: visibleHotels[index],
              saved: isSaved(visibleHotels[index].id),
              onToggleSaved: () => onToggleSaved(visibleHotels[index]),
              onTap: () {
                context.push(
                  HotelDetailScreen.pathFor(visibleHotels[index].id),
                  extra: query,
                );
              },
            ),
          ),
        _PaginationControls(
          currentPageIndex: safePageIndex,
          pageCount: pageCount,
          onPageChanged: onPageChanged,
        ),
      ],
    );
  }
}

class _PaginationControls extends StatefulWidget {
  const _PaginationControls({
    required this.currentPageIndex,
    required this.pageCount,
    required this.onPageChanged,
  });

  final int currentPageIndex;
  final int pageCount;
  final void Function(int pageIndex, int pageCount) onPageChanged;

  @override
  State<_PaginationControls> createState() => _PaginationControlsState();
}

class _PaginationControlsState extends State<_PaginationControls> {
  late final TextEditingController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = TextEditingController(
      text: (widget.currentPageIndex + 1).toString(),
    );
  }

  @override
  void didUpdateWidget(covariant _PaginationControls oldWidget) {
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
    final currentPage = widget.currentPageIndex + 1;

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
              'Page $currentPage of ${widget.pageCount}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

List<HotelSearchResult> _sortHotels(
  List<HotelSearchResult> hotels,
  _HotelSortOption sortOption,
) {
  final sortedHotels = hotels.toList();

  switch (sortOption) {
    case _HotelSortOption.recommended:
      return sortedHotels;
    case _HotelSortOption.priceLowToHigh:
      sortedHotels.sort(
        (left, right) =>
            left.minimumPricePerNight.compareTo(right.minimumPricePerNight),
      );
    case _HotelSortOption.priceHighToLow:
      sortedHotels.sort(
        (left, right) =>
            right.minimumPricePerNight.compareTo(left.minimumPricePerNight),
      );
    case _HotelSortOption.name:
      sortedHotels.sort((left, right) => left.name.compareTo(right.name));
  }

  return sortedHotels;
}

class _HotelResultControls extends StatelessWidget {
  const _HotelResultControls({
    required this.cities,
    required this.selectedCity,
    required this.sortOption,
    required this.onCityChanged,
    required this.onSortChanged,
  });

  final List<String> cities;
  final String? selectedCity;
  final _HotelSortOption sortOption;
  final ValueChanged<String?> onCityChanged;
  final ValueChanged<_HotelSortOption> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Filter panel',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                DropdownButtonHideUnderline(
                  child: DropdownButton<_HotelSortOption>(
                    value: sortOption,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    items: const [
                      DropdownMenuItem(
                        value: _HotelSortOption.recommended,
                        child: Text('Recommended'),
                      ),
                      DropdownMenuItem(
                        value: _HotelSortOption.priceLowToHigh,
                        child: Text('Lowest price'),
                      ),
                      DropdownMenuItem(
                        value: _HotelSortOption.priceHighToLow,
                        child: Text('Highest price'),
                      ),
                      DropdownMenuItem(
                        value: _HotelSortOption.name,
                        child: Text('Name A-Z'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        onSortChanged(value);
                      }
                    },
                  ),
                ),
              ],
            ),
            if (cities.length > 1) ...[
              const SizedBox(height: AppSpacing.sm),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: ChoiceChip(
                        label: const Text('All cities'),
                        selected: selectedCity == null,
                        onSelected: (_) => onCityChanged(null),
                      ),
                    ),
                    for (final city in cities)
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: ChoiceChip(
                          label: Text(city),
                          selected: selectedCity == city,
                          onSelected: (_) => onCityChanged(city),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextFormField(
          controller: locationController,
          textInputAction: TextInputAction.search,
          onFieldSubmitted: (_) => onApplySearch(),
          labelText: 'Destination',
          hintText: 'City or destination',
        ),
        const SizedBox(height: AppSpacing.lg),
        _DateFieldButton(
          label: 'Check-in Date',
          value: AppFormatters.displayDate(query.checkInDate),
          onPressed: onPickDates,
        ),
        const SizedBox(height: AppSpacing.lg),
        _DateFieldButton(
          label: 'Check-out Date',
          value: AppFormatters.displayDate(query.checkOutDate),
          onPressed: onPickDates,
        ),
        const SizedBox(height: AppSpacing.lg),
        QuantityStepper(
          label: 'Guest Count',
          value: query.guestCount,
          minimum: 1,
          maximum: 30,
          onChanged: onGuestChanged,
        ),
        const SizedBox(height: AppSpacing.lg),
        QuantityStepper(
          label: 'Room Quantity',
          value: query.roomCount,
          minimum: 1,
          maximum: 10,
          onChanged: onRoomChanged,
        ),
        const SizedBox(height: AppSpacing.xl),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onApplySearch,
            child: const Text('Search'),
          ),
        ),
      ],
    );
  }
}

class _SearchCriteriaSummary extends StatelessWidget {
  const _SearchCriteriaSummary({required this.query});

  final HotelSearchQuery query;

  @override
  Widget build(BuildContext context) {
    final destination =
        query.location.trim().isEmpty ? 'All destinations' : query.location;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Search criteria summary',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(destination),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              '${AppFormatters.displayDate(query.checkInDate)} - '
              '${AppFormatters.displayDate(query.checkOutDate)} | '
              '${query.guestCount} guest${query.guestCount == 1 ? '' : 's'} | '
              '${query.roomCount} room${query.roomCount == 1 ? '' : 's'}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _DateFieldButton extends StatelessWidget {
  const _DateFieldButton({
    required this.label,
    required this.value,
    required this.onPressed,
  });

  final String label;
  final String value;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label, $value',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: onPressed,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: const Icon(Icons.calendar_month_rounded),
          ),
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ),
    );
  }
}

class _EmptySearchResult extends StatelessWidget {
  const _EmptySearchResult({
    this.message = 'No stays found',
    this.description =
        'Try another city, date range, or reduce the number of rooms.',
  });

  final String message;
  final String description;

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
              message,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              description,
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
  const _ErrorPanel({
    required this.error,
    required this.onRetry,
  });

  final Object error;
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
            const SizedBox(height: AppSpacing.xs),
            Text(
              AppErrorPresenter.friendlyMessage(error),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
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
