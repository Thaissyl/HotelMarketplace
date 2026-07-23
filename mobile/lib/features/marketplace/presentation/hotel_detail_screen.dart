import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../features/auth/application/auth_controller.dart';
import '../../../features/auth/domain/auth_models.dart';
import '../../../features/auth/presentation/login_screen.dart';
import '../../../features/bookings/domain/booking_draft.dart';
import '../../../features/bookings/presentation/booking_form_screen.dart';
import '../../../features/customer/application/customer_state.dart';
import '../../../shared/utils/app_formatters.dart';
import '../../../shared/widgets/app_error_presenter.dart';
import '../../../shared/widgets/srs_screen.dart';
import '../application/marketplace_providers.dart';
import '../domain/marketplace_models.dart';
import 'marketplace_screen.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hotel Detail Screen'),
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
      ),
      body: SafeArea(
        child: detail.when(
          loading: () => const SingleChildScrollView(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: DetailSkeleton(),
          ),
          error: (error, stackTrace) => _DetailError(
            error: error,
            onRetry: () => ref.invalidate(hotelDetailProvider(request)),
          ),
          data: (hotel) => _HotelDetailContent(
            hotel: hotel,
            query: query,
          ),
        ),
      ),
    );
  }
}

class _HotelDetailContent extends ConsumerStatefulWidget {
  const _HotelDetailContent({
    required this.hotel,
    required this.query,
  });

  final HotelDetail hotel;
  final HotelSearchQuery query;

  @override
  ConsumerState<_HotelDetailContent> createState() =>
      _HotelDetailContentState();
}

class _HotelDetailContentState extends ConsumerState<_HotelDetailContent> {
  int _galleryIndex = 0;
  int _selectedRoomIndex = 0;

  void _continueBooking(AvailableRoomType roomType) {
    final session = ref.read(authControllerProvider).userSession;
    if (session == null) {
      context.push(LoginScreen.routePath);
      return;
    }
    if (!session.roles.contains(UserRoleCode.customer.apiValue)) {
      AppErrorPresenter.showSnackBar(
        context,
        'Please use a Customer account to create a booking.',
      );
      return;
    }

    context.push(
      BookingFormScreen.routePath,
      extra: BookingDraft(
        hotel: widget.hotel,
        roomType: roomType,
        query: widget.query.copyWith(roomCount: 1),
      ),
    );
  }

  Future<void> _toggleSaved() async {
    final session = ref.read(authControllerProvider).userSession;
    if (session == null) {
      context.push(LoginScreen.routePath);
      return;
    }
    try {
      await ref
          .read(customerStateProvider.notifier)
          .toggleSavedHotelDetail(widget.hotel);
      if (mounted) {
        AppErrorPresenter.showSnackBar(context, 'Saved hotels updated.');
      }
    } catch (error) {
      if (mounted) {
        AppErrorPresenter.showSnackBar(context, error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomTypes = widget.hotel.availableRoomTypes;
    final selectedRoom = roomTypes.isEmpty
        ? null
        : roomTypes[_selectedRoomIndex.clamp(0, roomTypes.length - 1)];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SrsSectionTitle('Hotel Gallery'),
              const SizedBox(height: AppSpacing.sm),
              _HotelGallery(
                images: widget.hotel.images,
                selectedIndex: _galleryIndex,
                onPageChanged: (index) {
                  setState(() => _galleryIndex = index);
                },
              ),
              const SizedBox(height: AppSpacing.xl),
              const SrsSectionTitle('Hotel Information'),
              const SizedBox(height: AppSpacing.sm),
              Text(
                widget.hotel.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${widget.hotel.addressLine}, ${widget.hotel.city}',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if ((widget.hotel.description ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(widget.hotel.description!),
              ],
              if (widget.hotel.contactPhone.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text('Phone: ${widget.hotel.contactPhone}'),
              ],
              if (widget.hotel.contactEmail.isNotEmpty)
                Text('Email: ${widget.hotel.contactEmail}'),
              const SizedBox(height: AppSpacing.xl),
              const SrsSectionTitle('Amenities List'),
              const SizedBox(height: AppSpacing.sm),
              widget.hotel.amenities.isEmpty
                  ? const Text('No amenities have been published.')
                  : Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final amenity in widget.hotel.amenities)
                          Chip(label: Text(amenity.name)),
                      ],
                    ),
              const SizedBox(height: AppSpacing.xl),
              const SrsSectionTitle('Cancellation Policy'),
              const SizedBox(height: AppSpacing.sm),
              _CancellationPolicy(policy: widget.hotel.cancellationPolicy),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  const Expanded(child: SrsSectionTitle('Room Type List')),
                  TextButton(
                    onPressed: _toggleSaved,
                    child: const Text('Save Hotel'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if (roomTypes.isEmpty)
                const SrsPanel(
                  child: Text(
                    'No room type is available for the selected dates.',
                  ),
                )
              else
                for (var index = 0; index < roomTypes.length; index++) ...[
                  _RoomTypeRow(
                    roomType: roomTypes[index],
                    selected: index == _selectedRoomIndex,
                    onTap: () {
                      setState(() => _selectedRoomIndex = index);
                    },
                  ),
                  if (index < roomTypes.length - 1)
                    const SizedBox(height: AppSpacing.sm),
                ],
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: selectedRoom == null
                    ? null
                    : () => _continueBooking(selectedRoom),
                child: const Text('Select Room'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HotelGallery extends StatefulWidget {
  const _HotelGallery({
    required this.images,
    required this.selectedIndex,
    required this.onPageChanged,
  });

  final List<HotelImage> images;
  final int selectedIndex;
  final ValueChanged<int> onPageChanged;

  @override
  State<_HotelGallery> createState() => _HotelGalleryState();
}

class _HotelGalleryState extends State<_HotelGallery> {
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return const AspectRatio(
        aspectRatio: 2.2,
        child: ColoredBox(
          color: AppColors.surfaceSoft,
          child: Center(
            child: Icon(
              Icons.image_outlined,
              size: 56,
              color: AppColors.subtleInk,
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 2.2,
          child: Stack(
            children: [
              PageView.builder(
                controller: _controller,
                itemCount: widget.images.length,
                onPageChanged: widget.onPageChanged,
                itemBuilder: (context, index) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    child: Image.network(
                      widget.images[index].imageUrl,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (context, error, stackTrace) {
                        return const ColoredBox(
                          color: AppColors.surfaceSoft,
                          child: Center(
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
              if (widget.images.length > 1) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    tooltip: 'Previous image',
                    onPressed: widget.selectedIndex == 0
                        ? null
                        : () => _controller.previousPage(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOut,
                            ),
                    icon: const Icon(Icons.chevron_left, size: 36),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: 'Next image',
                    onPressed: widget.selectedIndex == widget.images.length - 1
                        ? null
                        : () => _controller.nextPage(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOut,
                            ),
                    icon: const Icon(Icons.chevron_right, size: 36),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 54,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: widget.images.length,
            separatorBuilder: (context, index) =>
                const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) {
              return InkWell(
                onTap: () => _controller.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                ),
                child: Container(
                  width: 64,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: index == widget.selectedIndex
                          ? AppColors.ink
                          : AppColors.outlineSoft,
                      width: index == widget.selectedIndex ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(AppRadii.xs),
                    image: DecorationImage(
                      image: NetworkImage(widget.images[index].imageUrl),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CancellationPolicy extends StatelessWidget {
  const _CancellationPolicy({required this.policy});

  final CancellationPolicy? policy;

  @override
  Widget build(BuildContext context) {
    final value = policy;
    if (value == null) {
      return const Text('No cancellation policy has been published.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value.name, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${value.refundPercentage.toStringAsFixed(0)}% refund when cancelled at least ${value.freeCancellationHours} hours before check-in.',
        ),
        if ((value.description ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(value.description!),
        ],
      ],
    );
  }
}

class _RoomTypeRow extends StatelessWidget {
  const _RoomTypeRow({
    required this.roomType,
    required this.selected,
    required this.onTap,
  });

  final AvailableRoomType roomType;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        side: BorderSide(
          color: selected ? AppColors.ink : AppColors.outlineSoft,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              const SizedBox(
                width: 88,
                height: 70,
                child: ColoredBox(
                  color: AppColors.surfaceSoft,
                  child: Icon(
                    Icons.image_outlined,
                    color: AppColors.subtleInk,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      roomType.name,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${roomType.totalGuestCapacity} guests - ${roomType.availableRoomCount} rooms available',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      '${AppFormatters.money(roomType.basePricePerNight)} per night',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected ? AppColors.ink : AppColors.subtleInk,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailError extends StatelessWidget {
  const _DetailError({
    required this.error,
    required this.onRetry,
  });

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: SrsPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppErrorPresenter.friendlyMessage(error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(
                onPressed: onRetry,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
