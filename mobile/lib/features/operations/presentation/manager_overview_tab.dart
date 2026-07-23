import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../shared/utils/app_formatters.dart';
import '../../../shared/widgets/app_error_presenter.dart';
import '../../../shared/widgets/srs_screen.dart';
import '../application/operations_providers.dart';
import '../domain/operations_models.dart';
import 'hotel_booking_list_screen.dart';
import 'owner_physical_room_management_screen.dart';
import 'owner_room_type_management_screen.dart';

class ManagerOverviewTab extends ConsumerWidget {
  const ManagerOverviewTab({
    super.key,
    required this.hotelId,
    required this.roles,
    required this.onOpenSection,
  });

  final String hotelId;
  final List<String> roles;
  final ValueChanged<int>? onOpenSection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsRequest = PhysicalRoomsRequest(hotelId: hotelId);
    final bookingsRequest = FrontDeskBookingsRequest(hotelId: hotelId);
    final housekeepingRequest = HousekeepingTasksRequest(hotelId: hotelId);
    final maintenanceRequest = MaintenanceRequestsRequest(hotelId: hotelId);

    final rooms = ref.watch(physicalRoomsProvider(roomsRequest));
    final bookings = ref.watch(frontDeskBookingsProvider(bookingsRequest));
    final housekeeping =
        ref.watch(housekeepingTasksProvider(housekeepingRequest));
    final maintenance =
        ref.watch(maintenanceRequestsProvider(maintenanceRequest));

    Future<void> refresh() async {
      ref.invalidate(workingHotelsProvider);
      ref.invalidate(physicalRoomsProvider(roomsRequest));
      ref.invalidate(frontDeskBookingsProvider(bookingsRequest));
      ref.invalidate(housekeepingTasksProvider(housekeepingRequest));
      ref.invalidate(maintenanceRequestsProvider(maintenanceRequest));
    }

    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          const SrsSectionTitle('Hotel Summary Cards'),
          const SizedBox(height: AppSpacing.sm),
          _SummaryCards(
            rooms: rooms.asData?.value ?? const [],
            bookings: bookings.asData?.value ?? const [],
            loading: rooms.isLoading || bookings.isLoading,
          ),
          const SizedBox(height: AppSpacing.xl),
          const SrsSectionTitle('Operational Metrics'),
          const SizedBox(height: AppSpacing.sm),
          _OperationalMetrics(
            rooms: rooms.asData?.value ?? const [],
            bookings: bookings.asData?.value ?? const [],
            housekeeping: housekeeping.asData?.value ?? const [],
            maintenance: maintenance.asData?.value ?? const [],
            loading: rooms.isLoading ||
                bookings.isLoading ||
                housekeeping.isLoading ||
                maintenance.isLoading,
            onBookingsTap: () => _open(
              context,
              HotelBookingListScreen(initialHotelId: hotelId),
            ),
            onRoomsTap: () => _open(
              context,
              OwnerPhysicalRoomManagementScreen(hotelId: hotelId),
            ),
            onHousekeepingTap:
                onOpenSection == null ? null : () => onOpenSection!(4),
            onMaintenanceTap:
                onOpenSection == null ? null : () => onOpenSection!(5),
          ),
          if (rooms.hasError ||
              bookings.hasError ||
              housekeeping.hasError ||
              maintenance.hasError) ...[
            const SizedBox(height: AppSpacing.md),
            _LoadNotice(onRetry: refresh),
          ],
          const SizedBox(height: AppSpacing.xl),
          const SrsSectionTitle('Navigation Menu'),
          const SizedBox(height: AppSpacing.sm),
          _NavigationMenu(
            hotelId: hotelId,
            roles: roles,
            onOpenSection: onOpenSection,
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (context) => screen),
    );
  }
}

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({
    required this.rooms,
    required this.bookings,
    required this.loading,
  });

  final List<RoomInventoryItem> rooms;
  final List<FrontDeskBookingSummary> bookings;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final todaysBookings = bookings.where((booking) {
      return DateUtils.isSameDay(booking.checkInDate, today);
    }).length;
    final todaysRevenue = bookings.where((booking) {
      return DateUtils.isSameDay(booking.createdAtUtc.toLocal(), today);
    }).fold<double>(0, (sum, booking) => sum + booking.totalAmount);
    final occupiedRooms =
        rooms.where((room) => room.status == 'Occupied').length;
    final occupancy =
        rooms.isEmpty ? 0 : ((occupiedRooms / rooms.length) * 100).round();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _SummaryCard(
            icon: Icons.bed_rounded,
            label: 'Total Rooms',
            value: loading ? '-' : rooms.length.toString(),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: _SummaryCard(
            icon: Icons.calendar_month_outlined,
            label: "Today's Bookings",
            value: loading ? '-' : todaysBookings.toString(),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: _SummaryCard(
            icon: Icons.attach_money_rounded,
            label: "Today's Revenue",
            value: loading ? '-' : _compactMoney(todaysRevenue),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: _SummaryCard(
            icon: Icons.bar_chart_rounded,
            label: 'Occupancy',
            value: loading ? '-' : '$occupancy%',
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 0.72,
      child: SrsPanel(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.surfaceSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.brandDark),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outlineSoft,
                borderRadius: BorderRadius.circular(AppRadii.xs),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OperationalMetrics extends StatelessWidget {
  const _OperationalMetrics({
    required this.rooms,
    required this.bookings,
    required this.housekeeping,
    required this.maintenance,
    required this.loading,
    required this.onBookingsTap,
    required this.onRoomsTap,
    required this.onHousekeepingTap,
    required this.onMaintenanceTap,
  });

  final List<RoomInventoryItem> rooms;
  final List<FrontDeskBookingSummary> bookings;
  final List<HousekeepingTask> housekeeping;
  final List<MaintenanceRequestItem> maintenance;
  final bool loading;
  final VoidCallback onBookingsTap;
  final VoidCallback onRoomsTap;
  final VoidCallback? onHousekeepingTap;
  final VoidCallback? onMaintenanceTap;

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final todaysBookings = bookings.where((booking) {
      return DateUtils.isSameDay(booking.checkInDate, today);
    }).length;
    final occupiedRooms =
        rooms.where((room) => room.status == 'Occupied').length;
    final pendingHousekeeping = housekeeping.where((task) {
      return task.status == HousekeepingTaskStatus.open.apiValue;
    }).length;
    final openMaintenance = maintenance.where((request) {
      return request.status == MaintenanceStatus.open.apiValue ||
          request.status == MaintenanceStatus.inProgress.apiValue;
    }).length;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _OperationalCard(
            icon: Icons.calendar_today_outlined,
            label: 'Bookings',
            value: loading ? '-' : todaysBookings.toString(),
            helper: 'Today',
            onTap: onBookingsTap,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: _OperationalCard(
            icon: Icons.meeting_room_outlined,
            label: 'Rooms',
            value: loading ? '-' : '$occupiedRooms / ${rooms.length}',
            helper: 'Occupied',
            onTap: onRoomsTap,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: _OperationalCard(
            icon: Icons.cleaning_services_outlined,
            label: 'Housekeeping',
            value: loading ? '-' : pendingHousekeeping.toString(),
            helper: 'Pending',
            onTap: onHousekeepingTap,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: _OperationalCard(
            icon: Icons.handyman_outlined,
            label: 'Maintenance',
            value: loading ? '-' : openMaintenance.toString(),
            helper: 'Open',
            onTap: onMaintenanceTap,
          ),
        ),
      ],
    );
  }
}

class _OperationalCard extends StatelessWidget {
  const _OperationalCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.helper,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final String helper;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 0.72,
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.outlineSoft),
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xs),
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: AppColors.brandDark),
                ),
                const SizedBox(height: AppSpacing.sm),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Text(
                  helper,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.mutedInk,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigationMenu extends StatelessWidget {
  const _NavigationMenu({
    required this.hotelId,
    required this.roles,
    required this.onOpenSection,
  });

  final String hotelId;
  final List<String> roles;
  final ValueChanged<int>? onOpenSection;

  @override
  Widget build(BuildContext context) {
    final items = <_NavigationItem>[
      _NavigationItem(
        label: 'Hotel Profile',
        icon: Icons.apartment_rounded,
        onTap: onOpenSection == null ? null : () => onOpenSection!(1),
      ),
      _NavigationItem(
        label: 'Rooms',
        icon: Icons.bed_rounded,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) =>
                OwnerRoomTypeManagementScreen(hotelId: hotelId),
          ),
        ),
      ),
      _NavigationItem(
        label: 'Staff',
        icon: Icons.people_outline_rounded,
        onTap: onOpenSection == null ? null : () => onOpenSection!(6),
      ),
      _NavigationItem(
        label: 'Front Desk',
        icon: Icons.room_service_outlined,
        onTap: onOpenSection == null ? null : () => onOpenSection!(3),
      ),
      _NavigationItem(
        label: 'Tasks',
        icon: Icons.assignment_turned_in_outlined,
        onTap: onOpenSection == null ? null : () => onOpenSection!(4),
      ),
    ];

    return Semantics(
      label: roles.contains('PropertyOwner')
          ? 'Property owner navigation'
          : 'Hotel manager navigation',
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.outlineSoft),
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var index = 0; index < items.length; index++) ...[
              ListTile(
                leading: Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  child: Icon(items[index].icon, color: AppColors.brandDark),
                ),
                title: Text(items[index].label),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: items[index].onTap,
              ),
              if (index < items.length - 1) const Divider(height: 1),
            ],
          ],
        ),
      ),
    );
  }
}

class _NavigationItem {
  const _NavigationItem({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
}

class _LoadNotice extends StatelessWidget {
  const _LoadNotice({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return SrsPanel(
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              AppErrorPresenter.friendlyMessage(
                const FormatException('Dashboard data is unavailable.'),
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

String _compactMoney(double value) {
  if (value >= 1000000000) {
    return '\$${(value / 1000000000).toStringAsFixed(1)}B';
  }
  if (value >= 1000000) {
    return '\$${(value / 1000000).toStringAsFixed(1)}M';
  }
  if (value >= 1000) {
    return '\$${(value / 1000).toStringAsFixed(0)}K';
  }
  return AppFormatters.money(value);
}
