import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_spacing.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../account/presentation/account_settings_screen.dart';
import '../../marketplace/presentation/marketplace_screen.dart';
import '../application/operations_providers.dart';
import '../application/selected_hotel_controller.dart';
import 'availability_calendar_tab.dart';
import 'front_desk_tab.dart';
import 'housekeeping_tab.dart';
import 'manager_overview_tab.dart';
import 'maintenance_tab.dart';
import 'owner_hotel_onboarding.dart';
import 'owner_property_tab.dart';
import 'staff_management_tab.dart';

class OperationsDashboardScreen extends ConsumerStatefulWidget {
  const OperationsDashboardScreen({super.key});

  static const String routeName = 'operations';
  static const String routePath = '/operations';

  @override
  ConsumerState<OperationsDashboardScreen> createState() =>
      _OperationsDashboardScreenState();
}

class _OperationsDashboardScreenState
    extends ConsumerState<OperationsDashboardScreen> {
  int _selectedSectionIndex = 0;
  bool _showHotelRegistration = false;

  @override
  Widget build(BuildContext context) {
    final selectedHotelState = ref.watch(selectedHotelControllerProvider);
    final userSession = ref.watch(authControllerProvider).userSession;
    final hotelIds = userSession?.hotelIds ?? const [];
    final selectedHotelId =
        selectedHotelState.value ?? (hotelIds.isEmpty ? null : hotelIds.first);
    final workingHotels = ref.watch(workingHotelsProvider).valueOrNull;
    final selectedHotelName = selectedHotelId == null
        ? null
        : workingHotels
            ?.where((hotel) => hotel.id == selectedHotelId)
            .firstOrNull
            ?.displayName;
    final roles = userSession?.roles ?? const [];
    final sections = _OperationSection.visibleFor(roles);
    final canUseCustomerMarketplace =
        roles.contains(UserRoleCode.customer.apiValue);
    final isPropertyOwner = roles.contains(UserRoleCode.propertyOwner.apiValue);
    if (sections.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Hotel operations'),
          actions: [_accountMenu()],
        ),
        body: const SafeArea(child: _NoOperationAccess()),
      );
    }

    if (_selectedSectionIndex >= sections.length) {
      _selectedSectionIndex = 0;
    }
    final selectedSection = sections[_selectedSectionIndex];
    final canReturnToOverview = sections.first == _OperationSection.overview &&
        selectedSection != _OperationSection.overview;
    final isOwnerOnboarding = isPropertyOwner && selectedHotelId == null;
    final isHotelRegistration =
        isPropertyOwner && (isOwnerOnboarding || _showHotelRegistration);
    final canReturnFromHotelRegistration =
        _showHotelRegistration && selectedHotelId != null;

    return Scaffold(
      appBar: AppBar(
        title: isHotelRegistration
            ? const Text('Hotel Registration Screen')
            : selectedSection != _OperationSection.overview &&
                    selectedHotelId != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(selectedSection.screenTitle),
                      Text(
                        selectedHotelName ?? 'Assigned hotel',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  )
                : Text(selectedSection.screenTitle),
        automaticallyImplyLeading: canReturnFromHotelRegistration ||
            canReturnToOverview ||
            canUseCustomerMarketplace,
        leading: canReturnFromHotelRegistration
            ? IconButton(
                tooltip: 'Back to dashboard',
                onPressed: () {
                  setState(() {
                    _showHotelRegistration = false;
                    _selectedSectionIndex = 0;
                  });
                },
                icon: const Icon(Icons.arrow_back_rounded),
              )
            : canReturnToOverview
                ? IconButton(
                    tooltip: 'Back to dashboard',
                    onPressed: () => setState(() => _selectedSectionIndex = 0),
                    icon: const Icon(Icons.arrow_back_rounded),
                  )
                : canUseCustomerMarketplace
                    ? IconButton(
                        tooltip: 'Back',
                        onPressed: () {
                          if (context.canPop()) {
                            context.pop();
                            return;
                          }
                          context.go(MarketplaceScreen.routePath);
                        },
                        icon: const Icon(Icons.arrow_back_rounded),
                      )
                    : null,
        actions: [
          _workspaceMenu(
            sections,
            canRegisterHotel: isPropertyOwner,
          ),
        ],
      ),
      body: SafeArea(
        child: isHotelRegistration
            ? OwnerHotelOnboarding(
                onRegistered: () {
                  if (!mounted) {
                    return;
                  }
                  setState(() {
                    _showHotelRegistration = false;
                    _selectedSectionIndex = 0;
                  });
                },
              )
            : selectedHotelId == null
                ? const _NoHotelScope()
                : KeyedSubtree(
                    key: ValueKey(
                      '${selectedSection.name}-$selectedHotelId',
                    ),
                    child: selectedSection == _OperationSection.overview
                        ? ManagerOverviewTab(
                            hotelId: selectedHotelId,
                            roles: roles,
                            onOpenSection: (sectionIndex) {
                              if (sectionIndex >= 0 &&
                                  sectionIndex < sections.length) {
                                setState(
                                  () => _selectedSectionIndex = sectionIndex,
                                );
                              }
                            },
                          )
                        : selectedSection.buildTab(selectedHotelId, roles),
                  ),
      ),
    );
  }

  Widget _accountMenu() {
    return PopupMenuButton<String>(
      tooltip: 'Account menu',
      onSelected: _handleMenuSelection,
      itemBuilder: (context) => const [
        PopupMenuItem<String>(
          value: 'profile',
          child: Text('User Profile'),
        ),
        PopupMenuItem<String>(
          value: 'logout',
          child: Text('Sign Out'),
        ),
      ],
    );
  }

  Widget _workspaceMenu(
    List<_OperationSection> sections, {
    required bool canRegisterHotel,
  }) {
    return PopupMenuButton<String>(
      tooltip: 'Workspace menu',
      onSelected: _handleMenuSelection,
      itemBuilder: (context) => [
        if (sections.length > 1)
          for (var index = 0; index < sections.length; index++)
            PopupMenuItem<String>(
              value: 'section:$index',
              child: Text(sections[index].label),
            ),
        if (sections.length > 1) const PopupMenuDivider(),
        if (canRegisterHotel)
          const PopupMenuItem<String>(
            value: 'register-hotel',
            child: Text('Register New Hotel'),
          ),
        if (canRegisterHotel) const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'profile',
          child: Text('User Profile'),
        ),
        const PopupMenuItem<String>(
          value: 'logout',
          child: Text('Sign Out'),
        ),
      ],
    );
  }

  void _handleMenuSelection(String value) {
    if (value == 'profile') {
      context.push(AccountSettingsScreen.routePath);
      return;
    }

    if (value == 'logout') {
      ref.read(authControllerProvider.notifier).logout();
      return;
    }

    if (value == 'register-hotel') {
      setState(() => _showHotelRegistration = true);
      return;
    }

    if (value.startsWith('section:')) {
      final index = int.tryParse(value.substring('section:'.length));
      if (index != null) {
        setState(() {
          _showHotelRegistration = false;
          _selectedSectionIndex = index;
        });
      }
    }
  }
}

enum _OperationSection {
  overview(label: 'Overview'),
  frontDesk(label: 'Front Desk'),
  availability(label: 'Availability'),
  housekeeping(label: 'Housekeeping'),
  maintenance(label: 'Maintenance'),
  staff(label: 'Staff'),
  property(label: 'Property');

  const _OperationSection({
    required this.label,
  });

  final String label;

  String get screenTitle => switch (this) {
        overview => 'Owner/Manager Dashboard',
        frontDesk => 'Front Desk Dashboard',
        availability => 'Availability Calendar',
        housekeeping => 'Housekeeping Dashboard',
        maintenance => 'Maintenance Requests',
        staff => 'Staff Management',
        property => 'Hotel Profile Management',
      };

  static List<_OperationSection> visibleFor(List<String> roles) {
    final hasAllHotelOperations = roles.any((role) {
      return role == UserRoleCode.propertyOwner.apiValue ||
          role == UserRoleCode.hotelManager.apiValue;
    });

    if (hasAllHotelOperations) {
      return [
        overview,
        property,
        availability,
        frontDesk,
        housekeeping,
        maintenance,
        staff,
      ];
    }

    return [
      if (roles.contains(UserRoleCode.receptionist.apiValue)) ...[
        frontDesk,
        availability,
      ],
      if (roles.contains(UserRoleCode.housekeepingStaff.apiValue)) housekeeping,
      if (roles.contains(UserRoleCode.maintenanceStaff.apiValue)) maintenance,
    ];
  }

  Widget buildTab(String hotelId, List<String> roles) {
    return switch (this) {
      _OperationSection.overview => ManagerOverviewTab(
          hotelId: hotelId,
          roles: roles,
          onOpenSection: null,
        ),
      _OperationSection.frontDesk => FrontDeskTab(hotelId: hotelId),
      _OperationSection.availability => AvailabilityCalendarTab(
          hotelId: hotelId,
          roles: roles,
        ),
      _OperationSection.housekeeping => HousekeepingTab(hotelId: hotelId),
      _OperationSection.maintenance => MaintenanceTab(hotelId: hotelId),
      _OperationSection.staff => StaffManagementTab(hotelId: hotelId),
      _OperationSection.property => OwnerPropertyTab(hotelId: hotelId),
    };
  }
}

class _NoHotelScope extends StatelessWidget {
  const _NoHotelScope();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(
          'Your account is not assigned to any hotel yet.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}

class _NoOperationAccess extends StatelessWidget {
  const _NoOperationAccess();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(
          'Your account does not have a hotel operations role.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}
