import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../features/bookings/domain/booking_draft.dart';
import '../../../features/bookings/presentation/booking_confirmation_screen.dart';
import '../../../features/customer/application/customer_state.dart';
import '../../../shared/utils/app_formatters.dart';
import '../../../shared/widgets/app_error_presenter.dart';
import '../application/marketplace_providers.dart';
import '../domain/marketplace_models.dart';
import 'widgets/quantity_stepper.dart';
import 'widgets/marketplace_skeletons.dart';

class HotelDetailScreen extends ConsumerStatefulWidget {
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
  ConsumerState<HotelDetailScreen> createState() => _HotelDetailScreenState();
}

class _HotelDetailScreenState extends ConsumerState<HotelDetailScreen> {
  late HotelSearchQuery _draftQuery;
  late HotelSearchQuery _appliedQuery;
  Timer? _queryDebounce;
  HotelDetail? _lastHotel;
  bool _isRefreshingAvailability = false;

  @override
  void initState() {
    super.initState();
    _draftQuery = widget.query;
    _appliedQuery = widget.query;
  }

  @override
  void dispose() {
    _queryDebounce?.cancel();
    super.dispose();
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(
        start: _draftQuery.checkInDate,
        end: _draftQuery.checkOutDate,
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

    _scheduleAvailabilityRefresh(
      _draftQuery.copyWith(
        checkInDate: picked.start,
        checkOutDate: picked.end,
      ),
    );
  }

  void _scheduleAvailabilityRefresh(HotelSearchQuery query) {
    _queryDebounce?.cancel();
    setState(() {
      _draftQuery = query;
      _isRefreshingAvailability = true;
    });

    _queryDebounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) {
        return;
      }

      setState(() {
        _appliedQuery = _draftQuery;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final request = HotelDetailRequest(
      hotelId: widget.hotelId,
      query: _appliedQuery,
    );
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
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/customer');
            }
          },
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        child: detail.when(
          data: (hotel) {
            _lastHotel = hotel;
            _isRefreshingAvailability = false;
            return _HotelDetailContent(
              hotel: hotel,
              query: _draftQuery,
              isRefreshingAvailability: false,
              onPickDates: _pickDateRange,
              onGuestChanged: (value) {
                _scheduleAvailabilityRefresh(
                  _draftQuery.copyWith(guestCount: value),
                );
              },
              onRoomChanged: (value) {
                _scheduleAvailabilityRefresh(
                  _draftQuery.copyWith(roomCount: value),
                );
              },
            );
          },
          error: (error, stackTrace) => _DetailError(
            onRetry: () => ref.invalidate(hotelDetailProvider(request)),
          ),
          loading: () {
            final lastHotel = _lastHotel;
            if (lastHotel != null) {
              return _HotelDetailContent(
                hotel: lastHotel,
                query: _draftQuery,
                isRefreshingAvailability: _isRefreshingAvailability,
                onPickDates: _pickDateRange,
                onGuestChanged: (value) {
                  _scheduleAvailabilityRefresh(
                    _draftQuery.copyWith(guestCount: value),
                  );
                },
                onRoomChanged: (value) {
                  _scheduleAvailabilityRefresh(
                    _draftQuery.copyWith(roomCount: value),
                  );
                },
              );
            }

            return const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: DetailSkeleton(),
            );
          },
        ),
      ),
    );
  }
}

class _HotelDetailContent extends StatefulWidget {
  const _HotelDetailContent({
    required this.hotel,
    required this.query,
    required this.isRefreshingAvailability,
    required this.onPickDates,
    required this.onGuestChanged,
    required this.onRoomChanged,
  });

  final HotelDetail hotel;
  final HotelSearchQuery query;
  final bool isRefreshingAvailability;
  final VoidCallback onPickDates;
  final ValueChanged<int> onGuestChanged;
  final ValueChanged<int> onRoomChanged;

  @override
  State<_HotelDetailContent> createState() => _HotelDetailContentState();
}

class _HotelDetailContentState extends State<_HotelDetailContent> {
  int _selectedRoomTypeIndex = 0;

  @override
  Widget build(BuildContext context) {
    final roomTypes = widget.hotel.availableRoomTypes;
    final selectedRoomType = roomTypes.isEmpty
        ? null
        : roomTypes[_selectedRoomTypeIndex.clamp(0, roomTypes.length - 1)];

    return Stack(
      children: [
        if (widget.isRefreshingAvailability)
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: LinearProgressIndicator(minHeight: 2),
          ),
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.xl,
            AppSpacing.xl,
            112,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HotelHeaderCard(hotel: widget.hotel),
              if (widget.hotel.images.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                _HotelGallery(images: widget.hotel.images),
              ],
              if (widget.hotel.amenities.isNotEmpty ||
                  widget.hotel.cancellationPolicy != null) ...[
                const SizedBox(height: AppSpacing.lg),
                _HotelInformation(hotel: widget.hotel),
              ],
              const SizedBox(height: AppSpacing.md),
              _StayEditor(
                query: widget.query,
                onPickDates: widget.onPickDates,
                onGuestChanged: widget.onGuestChanged,
                onRoomChanged: widget.onRoomChanged,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Available rooms',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              if (roomTypes.isEmpty)
                const _NoRoomsCard()
              else
                for (var index = 0; index < roomTypes.length; index += 1)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: index == roomTypes.length - 1 ? 0 : AppSpacing.md,
                    ),
                    child: _RoomTypeCard(
                      roomType: roomTypes[index],
                      selected: index == _selectedRoomTypeIndex,
                      onSelect: () {
                        setState(() {
                          _selectedRoomTypeIndex = index;
                        });
                      },
                    ),
                  ),
            ],
          ),
        ),
        if (selectedRoomType != null)
          Positioned(
            left: AppSpacing.xl,
            right: AppSpacing.xl,
            bottom: AppSpacing.xl,
            child: SafeArea(
              top: false,
              child: FilledButton(
                onPressed: () {
                  context.push(
                    BookingConfirmationScreen.routePath,
                    extra: BookingDraft(
                      hotel: widget.hotel,
                      roomType: selectedRoomType,
                      query: widget.query,
                    ),
                  );
                },
                child: Text(
                  'Reserve ${AppFormatters.money(selectedRoomType.totalPriceForStay)}',
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _HotelGallery extends StatelessWidget {
  const _HotelGallery({required this.images});

  final List<HotelImage> images;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 210,
      child: PageView.builder(
        itemCount: images.length,
        itemBuilder: (context, index) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.md),
            child: Image.network(
              images[index].imageUrl,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              errorBuilder: (context, error, stackTrace) {
                return const ColoredBox(
                  color: AppColors.surfaceSoft,
                  child: Center(child: Icon(Icons.broken_image_outlined)),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _HotelInformation extends StatelessWidget {
  const _HotelInformation({required this.hotel});

  final HotelDetail hotel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final policy = hotel.cancellationPolicy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hotel.amenities.isNotEmpty) ...[
          Text('Amenities', style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: hotel.amenities
                .map(
                  (amenity) => Chip(
                    avatar: const Icon(Icons.check_circle_outline, size: 18),
                    label: Text(amenity.name),
                  ),
                )
                .toList(growable: false),
          ),
        ],
        if (policy != null) ...[
          if (hotel.amenities.isNotEmpty) const SizedBox(height: AppSpacing.lg),
          Text('Cancellation policy', style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(policy.name, style: textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            '${policy.refundPercentage.toStringAsFixed(0)}% refund when cancelled at least ${policy.freeCancellationHours} hours before arrival.',
            style: textTheme.bodyMedium,
          ),
          if ((policy.description ?? '').isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(policy.description!, style: textTheme.bodyMedium),
          ],
        ],
      ],
    );
  }
}

class _HotelHeaderCard extends ConsumerWidget {
  const _HotelHeaderCard({required this.hotel});

  final HotelDetail hotel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final saved = ref.watch(customerStateProvider).savedHotels.any(
          (savedHotel) => savedHotel.id == hotel.id,
        );

    return Card(
      color: AppColors.brand,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hotel.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.titleLarge?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: AppSpacing.md),
            _HeaderInfoRow(
              icon: Icons.location_on_outlined,
              text: '${hotel.addressLine}, ${hotel.city}',
            ),
            if (hotel.contactPhone.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              _HeaderInfoRow(
                icon: Icons.phone_outlined,
                text: hotel.contactPhone,
              ),
            ],
            if (hotel.contactEmail.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              _HeaderInfoRow(
                icon: Icons.mail_outline_rounded,
                text: hotel.contactEmail,
              ),
            ],
            if ((hotel.description ?? '').isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                hotel.description!,
                style: textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.82),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.72)),
              ),
              onPressed: () {
                ref
                    .read(customerStateProvider.notifier)
                    .toggleSavedHotelDetail(hotel);
              },
              icon: Icon(
                saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              ),
              label: Text(saved ? 'Saved hotel' : 'Save this hotel'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderInfoRow extends StatelessWidget {
  const _HeaderInfoRow({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.86), size: 18),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.86),
                ),
          ),
        ),
      ],
    );
  }
}

class _StayEditor extends StatelessWidget {
  const _StayEditor({
    required this.query,
    required this.onPickDates,
    required this.onGuestChanged,
    required this.onRoomChanged,
  });

  final HotelSearchQuery query;
  final VoidCallback onPickDates;
  final ValueChanged<int> onGuestChanged;
  final ValueChanged<int> onRoomChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Choose your stay',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: onPickDates,
              icon: const Icon(Icons.calendar_month_rounded),
              label: Text(
                '${AppFormatters.displayDate(query.checkInDate)} - ${AppFormatters.displayDate(query.checkOutDate)}',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            QuantityStepper(
              label: 'Guests',
              value: query.guestCount,
              minimum: 1,
              maximum: 30,
              onChanged: onGuestChanged,
            ),
            const SizedBox(height: AppSpacing.md),
            QuantityStepper(
              label: 'Rooms',
              value: query.roomCount,
              minimum: 1,
              maximum: 10,
              onChanged: onRoomChanged,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Availability below updates for ${query.nights} night${query.nights == 1 ? '' : 's'}.',
              style: Theme.of(context).textTheme.bodySmall,
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
    required this.selected,
    required this.onSelect,
  });

  final AvailableRoomType roomType;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? AppColors.brand : AppColors.outline,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(16),
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
                  if (selected) ...[
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.brand,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Text(
                    AppFormatters.money(roomType.basePricePerNight),
                    style: textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${roomType.totalGuestCapacity} guests - ${roomType.availableRoomCount} rooms left',
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
              if ((roomType.facilities ?? '').isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.room_preferences_outlined, size: 18),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        roomType.facilities!,
                        style: textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Text(
                '${AppFormatters.money(roomType.totalPriceForStay)} total',
                style: textTheme.labelLarge,
              ),
            ],
          ),
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
