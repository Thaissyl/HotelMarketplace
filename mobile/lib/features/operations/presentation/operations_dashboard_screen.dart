import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../application/selected_hotel_controller.dart';
import 'front_desk_tab.dart';
import 'housekeeping_tab.dart';
import 'maintenance_tab.dart';
import 'widgets/hotel_scope_selector.dart';

class OperationsDashboardScreen extends ConsumerWidget {
  const OperationsDashboardScreen({super.key});

  static const String routeName = 'operations';
  static const String routePath = '/operations';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedHotelId = ref.watch(selectedHotelControllerProvider).value;
    final roles = ref.watch(authControllerProvider).userSession?.roles ?? const [];
    final sections = _OperationSection.visibleFor(roles);

    if (sections.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Hotel operations')),
        body: const SafeArea(child: _NoOperationAccess()),
      );
    }

    return DefaultTabController(
      length: sections.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Hotel operations'),
          bottom: TabBar(
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
              Expanded(
                child: selectedHotelId == null
                    ? const _NoHotelScope()
                    : TabBarView(
                        children: [
                          for (final section in sections)
                            section.buildTab(selectedHotelId),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _OperationSection {
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
      return _OperationSection.values;
    }

    return [
      if (roles.contains(UserRoleCode.receptionist.apiValue)) frontDesk,
      if (roles.contains(UserRoleCode.housekeepingStaff.apiValue)) housekeeping,
      if (roles.contains(UserRoleCode.maintenanceStaff.apiValue)) maintenance,
    ];
  }

  Widget buildTab(String hotelId) {
    return switch (this) {
      _OperationSection.frontDesk => FrontDeskTab(hotelId: hotelId),
      _OperationSection.housekeeping => HousekeepingTab(hotelId: hotelId),
      _OperationSection.maintenance => MaintenanceTab(hotelId: hotelId),
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
