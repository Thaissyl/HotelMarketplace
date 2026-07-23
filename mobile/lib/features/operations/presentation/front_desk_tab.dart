import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../shared/utils/app_formatters.dart';
import '../application/operations_providers.dart';
import '../domain/operations_models.dart';
import 'arrival_departure_screen.dart';
import 'front_desk_components.dart';
import 'walk_in_screen.dart';

class FrontDeskTab extends ConsumerWidget {
  const FrontDeskTab({super.key, required this.hotelId});

  final String hotelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final confirmedRequest = FrontDeskBookingsRequest(
      hotelId: hotelId,
      status: FrontDeskBookingListStatus.confirmed,
    );
    final checkedInRequest = FrontDeskBookingsRequest(
      hotelId: hotelId,
      status: FrontDeskBookingListStatus.checkedIn,
    );
    final roomsRequest = PhysicalRoomsRequest(hotelId: hotelId);
    final confirmed = ref.watch(frontDeskBookingsProvider(confirmedRequest));
    final checkedIn = ref.watch(frontDeskBookingsProvider(checkedInRequest));
    final rooms = ref.watch(physicalRoomsProvider(roomsRequest));

    if (confirmed.hasError) {
      return FrontDeskErrorState(
        error: confirmed.error!,
        title: 'Unable to load front desk bookings',
        onRetry: () =>
            ref.invalidate(frontDeskBookingsProvider(confirmedRequest)),
      );
    }
    if (checkedIn.hasError) {
      return FrontDeskErrorState(
        error: checkedIn.error!,
        title: 'Unable to load in-house guests',
        onRetry: () =>
            ref.invalidate(frontDeskBookingsProvider(checkedInRequest)),
      );
    }
    if (rooms.hasError) {
      return FrontDeskErrorState(
        error: rooms.error!,
        title: 'Unable to load room status',
        onRetry: () => ref.invalidate(physicalRoomsProvider(roomsRequest)),
      );
    }
    if (confirmed.isLoading || checkedIn.isLoading || rooms.isLoading) {
      return const FrontDeskLoadingState();
    }

    final confirmedBookings = confirmed.value ?? const [];
    final checkedInBookings = checkedIn.value ?? const [];
    final roomItems = rooms.value ?? const [];
    final today = DateUtils.dateOnly(DateTime.now());
    final arrivals = confirmedBookings
        .where((booking) => DateUtils.isSameDay(booking.checkInDate, today))
        .toList(growable: false)
      ..sort((left, right) => left.bookingCode.compareTo(right.bookingCode));
    final departures = checkedInBookings
        .where((booking) => DateUtils.isSameDay(booking.checkOutDate, today))
        .toList(growable: false)
      ..sort((left, right) => left.bookingCode.compareTo(right.bookingCode));
    final noShows = confirmedBookings
        .where(
          (booking) => DateUtils.dateOnly(booking.checkInDate).isBefore(today),
        )
        .toList(growable: false)
      ..sort((left, right) => left.checkInDate.compareTo(right.checkInDate));

    Future<void> refresh() async {
      ref
        ..invalidate(frontDeskBookingsProvider(confirmedRequest))
        ..invalidate(frontDeskBookingsProvider(checkedInRequest))
        ..invalidate(physicalRoomsProvider(roomsRequest));
    }

    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _FrontDeskSummaryCard(
            title: 'Arrivals Card',
            count: arrivals.length,
            descriptionLabel: 'Next Arrival',
            booking: arrivals.firstOrNull,
            icon: Icons.person_outline,
            onTap: () => _openList(
              context,
              ref,
              ArrivalDepartureListType.arrivals,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _FrontDeskSummaryCard(
            title: 'Departures Card',
            count: departures.length,
            descriptionLabel: 'Next Departure',
            booking: departures.firstOrNull,
            icon: Icons.person_outline,
            useCheckOutDate: true,
            onTap: () => _openList(
              context,
              ref,
              ArrivalDepartureListType.departures,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _InHouseCard(
            count: checkedInBookings.length,
            onTap: () => _openList(
              context,
              ref,
              ArrivalDepartureListType.inHouse,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _NoShowCard(
            bookings: noShows,
            onTap: () => _openList(
              context,
              ref,
              ArrivalDepartureListType.noShow,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _RoomStatusSummary(rooms: roomItems),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            onPressed: () async {
              final result =
                  await Navigator.of(context).push<FrontDeskBookingResult>(
                MaterialPageRoute(
                  builder: (context) => WalkInBookingScreen(hotelId: hotelId),
                ),
              );
              if (result != null && context.mounted) {
                await refresh();
                if (context.mounted) {
                  showFrontDeskResult(context, result);
                }
              }
            },
            child: const Text('Create Walk-in Booking'),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  Future<void> _openList(
    BuildContext context,
    WidgetRef ref,
    ArrivalDepartureListType type,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => ArrivalDepartureScreen(
          hotelId: hotelId,
          initialType: type,
        ),
      ),
    );
    ref
      ..invalidate(
        frontDeskBookingsProvider(
          FrontDeskBookingsRequest(
            hotelId: hotelId,
            status: FrontDeskBookingListStatus.confirmed,
          ),
        ),
      )
      ..invalidate(
        frontDeskBookingsProvider(
          FrontDeskBookingsRequest(
            hotelId: hotelId,
            status: FrontDeskBookingListStatus.checkedIn,
          ),
        ),
      )
      ..invalidate(
        physicalRoomsProvider(PhysicalRoomsRequest(hotelId: hotelId)),
      );
  }
}

class _FrontDeskSummaryCard extends StatelessWidget {
  const _FrontDeskSummaryCard({
    required this.title,
    required this.count,
    required this.descriptionLabel,
    required this.booking,
    required this.icon,
    required this.onTap,
    this.useCheckOutDate = false,
  });

  final String title;
  final int count;
  final String descriptionLabel;
  final FrontDeskBookingSummary? booking;
  final IconData icon;
  final VoidCallback onTap;
  final bool useCheckOutDate;

  @override
  Widget build(BuildContext context) {
    final date = booking == null
        ? null
        : useCheckOutDate
            ? booking!.checkOutDate
            : booking!.checkInDate;

    return FrontDeskPanel(
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FrontDeskSectionTitle(
              title,
              trailing: Text(
                '$count',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                _CircleIcon(icon),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(descriptionLabel),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        booking?.guestFullName ?? 'No guest scheduled',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Icon(Icons.calendar_month_outlined),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        date == null
                            ? 'No date scheduled'
                            : _dashboardDate(date),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      const Text('Time not specified'),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                const Icon(Icons.chevron_right),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InHouseCard extends StatelessWidget {
  const _InHouseCard({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FrontDeskPanel(
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FrontDeskSectionTitle(
              'In-house Card',
              trailing: Text(
                '$count',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                const _CircleIcon(Icons.groups_outlined),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Guests Currently In-house'),
                      Text(
                        '$count',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NoShowCard extends StatelessWidget {
  const _NoShowCard({required this.bookings, required this.onTap});

  final List<FrontDeskBookingSummary> bookings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FrontDeskPanel(
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FrontDeskSectionTitle(
              'No-show Candidates',
              trailing: Text(
                '${bookings.length}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (bookings.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Text('No overdue confirmed arrivals.'),
              )
            else
              for (var index = 0;
                  index < bookings.length && index < 2;
                  index++) ...[
                if (index > 0) const Divider(),
                _NoShowGuestRow(booking: bookings[index]),
              ],
          ],
        ),
      ),
    );
  }
}

class _NoShowGuestRow extends StatelessWidget {
  const _NoShowGuestRow({required this.booking});

  final FrontDeskBookingSummary booking;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          const _CircleIcon(Icons.person_outline, size: 38),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.guestFullName,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(booking.bookingCode),
              ],
            ),
          ),
          const Icon(Icons.calendar_month_outlined),
          const SizedBox(width: AppSpacing.sm),
          Text(AppFormatters.displayDate(booking.checkInDate)),
          const SizedBox(width: AppSpacing.xs),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}

class _RoomStatusSummary extends StatelessWidget {
  const _RoomStatusSummary({required this.rooms});

  final List<RoomInventoryItem> rooms;

  @override
  Widget build(BuildContext context) {
    const statuses = [
      ('Available', Icons.check_circle_outline),
      ('Occupied', Icons.bed_outlined),
      ('Dirty', Icons.cleaning_services_outlined),
      ('Maintenance', Icons.build_outlined),
    ];

    return FrontDeskPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FrontDeskSectionTitle('Room Status Summary'),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              for (var index = 0; index < statuses.length; index++) ...[
                if (index > 0) const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Container(
                    height: 100,
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(statuses[index].$2),
                        const SizedBox(height: AppSpacing.xxs),
                        FittedBox(child: Text(statuses[index].$1)),
                        Text(
                          '${rooms.where((room) => room.status == statuses[index].$1).length}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _CircleIcon extends StatelessWidget {
  const _CircleIcon(this.icon, {this.size = 44});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Icon(icon),
    );
  }
}

String _dashboardDate(DateTime date) {
  final today = DateUtils.dateOnly(DateTime.now());
  final value = DateUtils.dateOnly(date);
  final prefix = DateUtils.isSameDay(today, value) ? 'Today, ' : '';
  return '$prefix${AppFormatters.displayDate(value)}';
}
