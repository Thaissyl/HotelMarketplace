import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_spacing.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../marketplace/presentation/marketplace_screen.dart';
import '../application/selected_hotel_controller.dart';
import 'front_desk_tab.dart';
import 'housekeeping_tab.dart';
import 'manager_overview_tab.dart';
import 'maintenance_tab.dart';
import 'owner_property_tab.dart';
import 'staff_management_tab.dart';
import 'widgets/hotel_scope_selector.dart';

class OperationsDashboardScreen extends ConsumerWidget {
  const OperationsDashboardScreen({super.key});

  static const String routeName = 'operations';
  static const String routePath = '/operations';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedHotelState = ref.watch(selectedHotelControllerProvider);
    final userSession = ref.watch(authControllerProvider).userSession;
    final hotelIds = userSession?.hotelIds ?? const [];
    final selectedHotelId = selectedHotelState.value ??
        (hotelIds.isEmpty ? null : hotelIds.first);
    final roles = userSession?.roles ?? const [];
    final sections = _OperationSection.visibleFor(roles);
    final canUseCustomerMarketplace =
        roles.contains(UserRoleCode.customer.apiValue);

    if (sections.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Hotel operations'),
          actions: [
            IconButton(
              tooltip: 'Sign out',
              onPressed: () {
                ref.read(authControllerProvider.notifier).logout();
              },
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
        ),
        body: const SafeArea(child: _NoOperationAccess()),
      );
    }

    return DefaultTabController(
      length: sections.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_workspaceTitle(roles)),
          automaticallyImplyLeading: canUseCustomerMarketplace,
          leading: canUseCustomerMarketplace
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
            IconButton(
              tooltip: 'Sign out',
              onPressed: () {
                ref.read(authControllerProvider.notifier).logout();
              },
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
          bottom: sections.length == 1
              ? null
              : TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    for (final section in sections)
                      Tab(icon: Icon(section.icon), text: section.label),
                  ],
                ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: HotelScopeSelector(),
              ),
              const Divider(height: 1),
              Expanded(
                child: selectedHotelId == null
                    ? const _NoHotelScope()
                    : sections.length == 1
                        ? KeyedSubtree(
                            key: ValueKey(
                              '${sections.first.name}-$selectedHotelId',
                            ),
                            child: sections.first.buildTab(
                              selectedHotelId,
                              roles,
                            ),
                          )
                        : TabBarView(
                            children: [
                              for (final section in sections)
                                KeyedSubtree(
                                  key: ValueKey(
                                    '${section.name}-$selectedHotelId',
                                  ),
                                  child: section.buildTab(
                                    selectedHotelId,
                                    roles,
                                  ),
                                ),
                            ],
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _workspaceTitle(List<String> roles) {
    if (roles.contains(UserRoleCode.propertyOwner.apiValue)) {
      return 'Property Management';
    }

    if (roles.contains(UserRoleCode.hotelManager.apiValue)) {
      return 'Hotel Manager';
    }

    if (roles.contains(UserRoleCode.receptionist.apiValue)) {
      return 'Front Desk';
    }

    if (roles.contains(UserRoleCode.housekeepingStaff.apiValue)) {
      return 'Housekeeping';
    }

    if (roles.contains(UserRoleCode.maintenanceStaff.apiValue)) {
      return 'Maintenance';
    }

    return 'Hotel operations';
  }
}

enum _OperationSection {
  overview(
    label: 'Overview',
    icon: Icons.dashboard_rounded,
  ),
  frontDesk(
    label: 'Front Desk',
    icon: Icons.room_service_rounded,
  ),
  housekeeping(
    label: 'Rooms',
    icon: Icons.cleaning_services_rounded,
  ),
  maintenance(
    label: 'Maintenance',
    icon: Icons.handyman_rounded,
  ),
  staff(
    label: 'Staff',
    icon: Icons.manage_accounts_rounded,
  ),
  property(
    label: 'Property',
    icon: Icons.apartment_rounded,
  );

  const _OperationSection({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;

  static List<_OperationSection> visibleFor(List<String> roles) {
    final hasAllHotelOperations = roles.any((role) {
      return role == UserRoleCode.propertyOwner.apiValue ||
          role == UserRoleCode.hotelManager.apiValue ||
          role == UserRoleCode.platformAdministrator.apiValue;
    });

    if (hasAllHotelOperations) {
      return [
        overview,
        if (roles.contains(UserRoleCode.propertyOwner.apiValue)) property,
        frontDesk,
        housekeeping,
        maintenance,
        if (roles.contains(UserRoleCode.propertyOwner.apiValue)) staff,
      ];
    }

    return [
      if (roles.contains(UserRoleCode.receptionist.apiValue)) frontDesk,
      if (roles.contains(UserRoleCode.housekeepingStaff.apiValue)) housekeeping,
      if (roles.contains(UserRoleCode.maintenanceStaff.apiValue)) maintenance,
    ];
  }

  Widget buildTab(String hotelId, List<String> roles) {
    return switch (this) {
      _OperationSection.overview => ManagerOverviewTab(
          hotelId: hotelId,
          roles: roles,
        ),
      _OperationSection.frontDesk => FrontDeskTab(hotelId: hotelId),
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
