import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../features/customer/application/customer_state.dart';
import '../../../shared/utils/app_formatters.dart';
import '../../../shared/widgets/app_error_presenter.dart';
import '../../../shared/widgets/srs_screen.dart';
import '../../marketplace/presentation/marketplace_screen.dart';
import '../application/booking_controller.dart';
import '../domain/booking_models.dart';
import 'customer_booking_detail_screen.dart';

class MyBookingsScreen extends ConsumerStatefulWidget {
  const MyBookingsScreen({super.key});

  static const String routeName = 'my-bookings';
  static const String routePath = '/bookings';

  @override
  ConsumerState<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends ConsumerState<MyBookingsScreen> {
  String _status = 'All';

  @override
  Widget build(BuildContext context) {
    final localBookings = ref.watch(customerStateProvider).bookings;
    final bookings = ref.watch(myBookingsProvider);

    return SrsScreen(
      title: 'My Bookings Screen',
      leading: IconButton(
        tooltip: 'Back',
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(MarketplaceScreen.routePath);
          }
        },
        icon: const Icon(Icons.arrow_back),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SrsSectionTitle('Status Filter'),
          const SizedBox(height: AppSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final status in const [
                  'All',
                  'PendingPayment',
                  'Confirmed',
                  'CheckedIn',
                  'Completed',
                  'Cancelled',
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ChoiceChip(
                      label: Text(_statusLabel(status)),
                      selected: _status == status,
                      onSelected: (_) => setState(() => _status = status),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          bookings.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) {
              if (localBookings.isNotEmpty) {
                return _BookingList(
                  bookings: _filterBookings(localBookings, _status),
                  offline: true,
                );
              }
              return SrsPanel(
                child: Column(
                  children: [
                    Text(
                      AppErrorPresenter.friendlyMessage(error),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton(
                      onPressed: () => ref.invalidate(myBookingsProvider),
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              );
            },
            data: (remoteBookings) {
              final merged = _mergeBookings(remoteBookings, localBookings);
              return _BookingList(
                bookings: _filterBookings(merged, _status),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BookingList extends StatelessWidget {
  const _BookingList({
    required this.bookings,
    this.offline = false,
  });

  final List<Booking> bookings;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return const SrsPanel(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
          child: Column(
            children: [
              Icon(
                Icons.event_note_outlined,
                size: 52,
                color: AppColors.subtleInk,
              ),
              SizedBox(height: AppSpacing.md),
              Text(
                'You do not have any bookings matching this status.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        if (offline) ...[
          const SrsPanel(
            child: Text(
              'Showing bookings saved during this session because the server could not be reached.',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        for (var index = 0; index < bookings.length; index++) ...[
          _BookingCard(booking: bookings[index]),
          if (index < bookings.length - 1)
            const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.outline),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    booking.bookingCode,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _StatusBadge(status: booking.status),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              (booking.hotelName ?? '').trim().isEmpty
                  ? 'Hotel information'
                  : booking.hotelName!,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            if ((booking.roomTypeName ?? '').trim().isNotEmpty)
              Text(
                booking.roomTypeName!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${AppFormatters.displayDate(booking.checkInDate)} - ${AppFormatters.displayDate(booking.checkOutDate)}',
            ),
            Text(
              '${booking.roomCount} room${booking.roomCount == 1 ? '' : 's'} - ${booking.guestCount} guest${booking.guestCount == 1 ? '' : 's'}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 160,
                child: FilledButton(
                  onPressed: () {
                    context.push(
                      CustomerBookingDetailScreen.pathFor(booking.id),
                      extra: booking,
                    );
                  },
                  child: const Text('View Detail'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(AppRadii.xs),
      ),
      child: Text(
        _statusLabel(status),
        style: Theme.of(context).textTheme.labelMedium,
      ),
    );
  }
}

List<Booking> _mergeBookings(List<Booking> remote, List<Booking> local) {
  final byId = <String, Booking>{
    for (final booking in local) booking.id: booking,
    for (final booking in remote) booking.id: booking,
  };
  final result = byId.values.toList(growable: false);
  result.sort((left, right) => right.createdAtUtc.compareTo(left.createdAtUtc));
  return result;
}

List<Booking> _filterBookings(List<Booking> bookings, String status) {
  if (status == 'All') {
    return bookings;
  }
  return bookings
      .where((booking) => booking.status == status)
      .toList(growable: false);
}

String _statusLabel(String status) {
  return switch (status) {
    'PendingPayment' => 'Pending Payment',
    'CheckedIn' => 'Checked In',
    _ => status,
  };
}
