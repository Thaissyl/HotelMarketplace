import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
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

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Hotel operations'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.room_service_rounded), text: 'Front Desk'),
              Tab(icon: Icon(Icons.cleaning_services_rounded), text: 'Rooms'),
              Tab(icon: Icon(Icons.handyman_rounded), text: 'Maintenance'),
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
                          FrontDeskTab(hotelId: selectedHotelId),
                          HousekeepingTab(hotelId: selectedHotelId),
                          MaintenanceTab(hotelId: selectedHotelId),
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
