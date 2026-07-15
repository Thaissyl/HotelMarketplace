import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../features/bookings/domain/booking_draft.dart';
import '../../../features/bookings/presentation/booking_confirmation_screen.dart';
import '../../../shared/utils/app_formatters.dart';
import '../../../shared/widgets/app_error_presenter.dart';
import '../application/marketplace_providers.dart';
import '../domain/marketplace_models.dart';
import 'widgets/marketplace_skeletons.dart';

class HotelDetailScreen extends ConsumerWidget {
  const HotelDetailScreen({
    super.key,
    required this.hotelId,
    required this.query,
  });

  static const String routeName = 'hotel-detail';
  static const String routePath = '/hotels/:hotelId';

  final String hotelId;
  final HotelSearchQuery query;

  static String pathFor(String hotelId) => '/hotels/$hotelId';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = HotelDetailRequest(hotelId: hotelId, query: query);
    final detail = ref.watch(hotelDetailProvider(request));

    ref.listen(hotelDetailProvider(request), (previous, next) {
      next.whenOrNull(
        error: (error, stackTrace) {
          AppErrorPresenter.showSnackBar(context, error);
        },
      );
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hotel details'),
      ),
      body: SafeArea(
        child: detail.when(
          data: (hotel) => _HotelDetailContent(
            hotel: hotel,
            query: query,
          ),
          error: (error, stackTrace) => _DetailError(
            onRetry: () => ref.invalidate(hotelDetailProvider(request)),
          ),
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: DetailSkeleton(),
          ),
        ),
      ),
    );
  }
}

class _HotelDetailContent extends StatelessWidget {
  const _HotelDetailContent({
    required this.hotel,
    required this.query,
  });

  final HotelDetail hotel;
  final HotelSearchQuery query;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Container(
          height: 220,
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: AppColors.brand,
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hotel.name,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${hotel.city} · ${hotel.addressLine}',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.white.withValues(alpha: 0.82)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        _StaySummary(query: query),
        if ((hotel.description ?? '').isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          Text('About', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            hotel.description!,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
        const SizedBox(height: AppSpacing.xxl),
        Text('Available rooms', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        if (hotel.availableRoomTypes.isEmpty)
          const _NoRoomsCard()
        else
          for (var index = 0;
              index < hotel.availableRoomTypes.length;
              index += 1)
            Padding(
              padding: EdgeInsets.only(
                bottom: index == hotel.availableRoomTypes.length - 1
                    ? 0
                    : AppSpacing.md,
              ),
              child: _RoomTypeCard(
                roomType: hotel.availableRoomTypes[index],
                onReserve: () {
                  context.go(
                    BookingConfirmationScreen.routePath,
                    extra: BookingDraft(
                      hotel: hotel,
                      roomType: hotel.availableRoomTypes[index],
                      query: query,
                    ),
                  );
                },
              ),
            ),
      ],
    );
  }
}

class _StaySummary extends StatelessWidget {
  const _StaySummary({required this.query});

  final HotelSearchQuery query;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_rounded),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                '${AppFormatters.displayDate(query.checkInDate)} - ${AppFormatters.displayDate(query.checkOutDate)} · ${query.guestCount} guests · ${query.roomCount} rooms',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomTypeCard extends StatelessWidget {
  const _RoomTypeCard({
    required this.roomType,
    required this.onReserve,
  });

  final AvailableRoomType roomType;
  final VoidCallback onReserve;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(roomType.name, style: textTheme.titleMedium),
                ),
                Text(
                  AppFormatters.money(roomType.basePricePerNight),
                  style: textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${roomType.totalGuestCapacity} guests · ${roomType.availableRoomCount} rooms left',
              style: textTheme.bodyMedium,
            ),
            if ((roomType.description ?? '').isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                roomType.description!,
                style: textTheme.bodyMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${AppFormatters.money(roomType.totalPriceForStay)} total',
                    style: textTheme.labelLarge,
                  ),
                ),
                FilledButton(
                  onPressed: onReserve,
                  child: const Text('Reserve'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NoRoomsCard extends StatelessWidget {
  const _NoRoomsCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(
          'No room type has enough availability for this stay.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

class _DetailError extends StatelessWidget {
  const _DetailError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.danger,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Unable to load hotel details',
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
        ),
      ),
    );
  }
}
