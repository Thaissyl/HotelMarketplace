import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../features/auth/application/auth_controller.dart';
import '../../../features/auth/presentation/login_screen.dart';
import '../../../features/account/presentation/account_settings_screen.dart';
import '../../../features/bookings/presentation/my_bookings_screen.dart';
import '../../../features/operations/presentation/operations_dashboard_screen.dart';
import '../../../features/platform_admin/presentation/platform_admin_dashboard_screen.dart';
import '../../../shared/utils/app_formatters.dart';
import '../../../shared/widgets/app_error_presenter.dart';
import '../../../shared/widgets/app_text_form_field.dart';
import '../../../shared/widgets/srs_screen.dart';
import '../application/marketplace_providers.dart';
import '../domain/marketplace_models.dart';
import 'hotel_search_results_screen.dart';
import 'widgets/quantity_stepper.dart';

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
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _destination;
  late HotelSearchQuery _draftQuery;

  @override
  void initState() {
    super.initState();
    _draftQuery = ref.read(hotelSearchQueryProvider);
    _destination = TextEditingController(text: _draftQuery.location);
  }

  @override
  void dispose() {
    _destination.dispose();
    super.dispose();
  }

  Future<void> _pickCheckInDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final selected = await showDatePicker(
      context: context,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      initialDate: _draftQuery.checkInDate.isBefore(today)
          ? today
          : _draftQuery.checkInDate,
    );
    if (selected == null) {
      return;
    }

    final nextCheckOut = _draftQuery.checkOutDate.isAfter(selected)
        ? _draftQuery.checkOutDate
        : selected.add(const Duration(days: 1));
    setState(() {
      _draftQuery = _draftQuery.copyWith(
        checkInDate: selected,
        checkOutDate: nextCheckOut,
      );
    });
  }

  Future<void> _pickCheckOutDate() async {
    final firstDate = _draftQuery.checkInDate.add(const Duration(days: 1));
    final selected = await showDatePicker(
      context: context,
      firstDate: firstDate,
      lastDate: _draftQuery.checkInDate.add(const Duration(days: 365)),
      initialDate: _draftQuery.checkOutDate.isBefore(firstDate)
          ? firstDate
          : _draftQuery.checkOutDate,
    );
    if (selected != null) {
      setState(() {
        _draftQuery = _draftQuery.copyWith(checkOutDate: selected);
      });
    }
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<HotelSearchFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _SearchFiltersSheet(
        initialFilters: _draftQuery.filters,
      ),
    );

    if (result != null) {
      setState(() {
        _draftQuery = _draftQuery.copyWith(filters: result);
      });
    }
  }

  void _search() {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState?.validate() != true) {
      return;
    }
    if (!_draftQuery.checkOutDate.isAfter(_draftQuery.checkInDate)) {
      AppErrorPresenter.showSnackBar(
        context,
        'The check-out date must be later than the check-in date.',
      );
      return;
    }

    final query = _draftQuery.copyWith(
      location: _destination.text.trim(),
      roomCount: 1,
    );
    ref.read(hotelSearchQueryProvider.notifier).state = query;
    context.push(HotelSearchResultsScreen.routePath, extra: query);
  }

  @override
  Widget build(BuildContext context) {
    final content = Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextFormField(
            controller: _destination,
            labelText: 'Destination',
            externalLabel: true,
            required: true,
            textInputAction: TextInputAction.next,
            validator: (value) {
              final destination = value?.trim() ?? '';
              if (destination.isEmpty) {
                return 'Please enter a destination or hotel keyword.';
              }
              if (destination.length > 100) {
                return 'Destination must be 100 characters or fewer.';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.xxl),
          _DateInput(
            label: 'Check-in Date',
            value: _draftQuery.checkInDate,
            onPressed: _pickCheckInDate,
          ),
          const SizedBox(height: AppSpacing.xxl),
          _DateInput(
            label: 'Check-out Date',
            value: _draftQuery.checkOutDate,
            onPressed: _pickCheckOutDate,
          ),
          const SizedBox(height: AppSpacing.xxl),
          QuantityStepper(
            label: 'Guest Count',
            value: _draftQuery.guestCount,
            minimum: 1,
            maximum: 30,
            onChanged: (value) {
              setState(() {
                _draftQuery = _draftQuery.copyWith(guestCount: value);
              });
            },
          ),
          const SizedBox(height: AppSpacing.xl),
          const SrsSectionTitle('Filters'),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _FilterChip(
                  label: _draftQuery.filters.hasPriceRange
                      ? 'Price applied'
                      : 'Price',
                  selected: _draftQuery.filters.hasPriceRange,
                  onPressed: _openFilters,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _FilterChip(
                  label: _draftQuery.filters.hasAmenities
                      ? '${_draftQuery.filters.amenities.length} amenities'
                      : 'Amenities',
                  selected: _draftQuery.filters.hasAmenities,
                  onPressed: _openFilters,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _FilterChip(
                  label: 'Available',
                  selected: _draftQuery.filters.availableOnly,
                  onPressed: () {
                    setState(() {
                      _draftQuery = _draftQuery.copyWith(
                        filters: _draftQuery.filters.copyWith(
                          availableOnly: !_draftQuery.filters.availableOnly,
                        ),
                      );
                    });
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _FilterChip(
                  label: 'More',
                  selected: _draftQuery.filters.isActive,
                  onPressed: _openFilters,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          FilledButton(
            onPressed: _search,
            child: const Text('Search'),
          ),
        ],
      ),
    );

    if (!widget.showAppBar) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [content],
      );
    }

    return SrsScreen(
      title: 'Home / Search Screen',
      automaticallyImplyLeading: false,
      actions: [_MarketplaceAccountMenu(ref: ref)],
      child: content,
    );
  }
}

class _MarketplaceAccountMenu extends StatelessWidget {
  const _MarketplaceAccountMenu({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider).userSession;
    if (session == null) {
      return IconButton(
        tooltip: 'Login',
        onPressed: () => context.push(LoginScreen.routePath),
        icon: const Icon(Icons.login),
      );
    }

    return PopupMenuButton<_MarketplaceMenuAction>(
      tooltip: 'Account menu',
      onSelected: (action) {
        switch (action) {
          case _MarketplaceMenuAction.myBookings:
            context.push(MyBookingsScreen.routePath);
          case _MarketplaceMenuAction.profile:
            context.push(AccountSettingsScreen.routePath);
          case _MarketplaceMenuAction.operations:
            context.go(OperationsDashboardScreen.routePath);
          case _MarketplaceMenuAction.platformAdmin:
            context.go(PlatformAdminDashboardScreen.routePath);
          case _MarketplaceMenuAction.signOut:
            ref.read(authControllerProvider.notifier).logout();
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: _MarketplaceMenuAction.myBookings,
          child: Text('My bookings'),
        ),
        const PopupMenuItem(
          value: _MarketplaceMenuAction.profile,
          child: Text('User profile'),
        ),
        if (session.hotelIds.isNotEmpty)
          const PopupMenuItem(
            value: _MarketplaceMenuAction.operations,
            child: Text('Hotel operations'),
          ),
        if (session.roles.contains('PlatformAdministrator'))
          const PopupMenuItem(
            value: _MarketplaceMenuAction.platformAdmin,
            child: Text('Platform administration'),
          ),
        const PopupMenuItem(
          value: _MarketplaceMenuAction.signOut,
          child: Text('Sign out'),
        ),
      ],
    );
  }
}

enum _MarketplaceMenuAction {
  myBookings,
  profile,
  operations,
  platformAdmin,
  signOut,
}

class _DateInput extends StatelessWidget {
  const _DateInput({
    required this.label,
    required this.value,
    required this.onPressed,
  });

  final String label;
  final DateTime value;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SrsFieldLabel(label, required: true),
        OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.ink,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          ),
          child: Row(
            children: [
              Expanded(child: Text(AppFormatters.displayDate(value))),
              const Icon(Icons.calendar_today_outlined),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: Size.zero,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
          backgroundColor: selected ? AppColors.surfaceSoft : AppColors.surface,
          side: BorderSide(
            color: selected ? AppColors.ink : AppColors.outline,
            width: selected ? 1.5 : 1,
          ),
          shape: const StadiumBorder(),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
      ),
    );
  }
}

class _SearchFiltersSheet extends StatefulWidget {
  const _SearchFiltersSheet({required this.initialFilters});

  final HotelSearchFilters initialFilters;

  @override
  State<_SearchFiltersSheet> createState() => _SearchFiltersSheetState();
}

class _SearchFiltersSheetState extends State<_SearchFiltersSheet> {
  static const _amenityOptions = <String>[
    'WiFi',
    'Breakfast',
    'Parking',
    'Swimming Pool',
  ];

  late final TextEditingController _minimumPrice;
  late final TextEditingController _maximumPrice;
  late final Set<String> _amenities;
  late bool _availableOnly;

  @override
  void initState() {
    super.initState();
    _minimumPrice = TextEditingController(
      text: widget.initialFilters.minimumPrice?.toStringAsFixed(0) ?? '',
    );
    _maximumPrice = TextEditingController(
      text: widget.initialFilters.maximumPrice?.toStringAsFixed(0) ?? '',
    );
    _amenities = widget.initialFilters.amenities.toSet();
    _availableOnly = widget.initialFilters.availableOnly;
  }

  @override
  void dispose() {
    _minimumPrice.dispose();
    _maximumPrice.dispose();
    super.dispose();
  }

  double? _priceOf(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : double.tryParse(text);
  }

  void _apply() {
    final minimumPrice = _priceOf(_minimumPrice);
    final maximumPrice = _priceOf(_maximumPrice);
    if (minimumPrice != null &&
        maximumPrice != null &&
        minimumPrice > maximumPrice) {
      AppErrorPresenter.showSnackBar(
        context,
        'Minimum price cannot exceed maximum price.',
      );
      return;
    }

    Navigator.of(context).pop(
      HotelSearchFilters(
        minimumPrice: minimumPrice,
        maximumPrice: maximumPrice,
        amenities: _amenities.toList(growable: false)..sort(),
        availableOnly: _availableOnly,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Filters', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: AppTextFormField(
                    controller: _minimumPrice,
                    labelText: 'Minimum Price',
                    externalLabel: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppTextFormField(
                    controller: _maximumPrice,
                    labelText: 'Maximum Price',
                    externalLabel: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const SrsSectionTitle('Amenities'),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final amenity in _amenityOptions)
                  FilterChip(
                    label: Text(amenity),
                    selected: _amenities.contains(amenity),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _amenities.add(amenity);
                        } else {
                          _amenities.remove(amenity);
                        }
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Available room types only'),
              value: _availableOnly,
              onChanged: (value) => setState(() => _availableOnly = value),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(onPressed: _apply, child: const Text('Apply Filters')),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(const HotelSearchFilters());
              },
              child: const Text('Reset Filters'),
            ),
          ],
        ),
      ),
    );
  }
}
