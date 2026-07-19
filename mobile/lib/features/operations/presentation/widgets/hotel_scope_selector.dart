import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../auth/application/auth_controller.dart';
import '../../application/operations_providers.dart';
import '../../application/selected_hotel_controller.dart';
import '../../domain/operations_models.dart';

class HotelScopeSelector extends ConsumerWidget {
  const HotelScopeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hotelIds =
        ref.watch(authControllerProvider).userSession?.hotelIds ?? const [];
    final selectedHotel = ref.watch(selectedHotelControllerProvider);
    final workingHotels = ref.watch(workingHotelsProvider);

    return Card(
      child: workingHotels.when(
        data: (hotels) {
          final loadedItems = hotels
              .where((hotel) => hotel.id.isNotEmpty)
              .map(_WorkingHotelItem.fromWorkingHotel)
              .toList(growable: true);
          if (hotelIds.isEmpty && loadedItems.isEmpty) {
            return const ListTile(
              leading: _HotelLeadingIcon(),
              title: Text('No hotel scope assigned'),
              subtitle: Text('This account is not assigned to a hotel yet.'),
            );
          }

          final missingItems = hotelIds
              .where((id) => loadedItems.every((hotel) => hotel.id != id))
              .map(_WorkingHotelItem.fallback);
          final hotelItems = [...loadedItems, ...missingItems];
          final selectedId = selectedHotel.value ?? hotelItems.first.id;
          final effectiveSelectedId =
              hotelItems.any((hotel) => hotel.id == selectedId)
                  ? selectedId
                  : hotelItems.first.id;

          if (effectiveSelectedId != selectedHotel.value) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref
                  .read(selectedHotelControllerProvider.notifier)
                  .selectHotel(effectiveSelectedId);
            });
          }

          final selectedHotelItem = hotelItems.firstWhere(
            (hotel) => hotel.id == effectiveSelectedId,
            orElse: () => hotelItems.first,
          );

          return InkWell(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            onTap: () => _showHotelDetails(context, selectedHotelItem),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const _HotelLeadingIcon(),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedHotelItem.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _SelectedHotelSummary(
                          hotel: selectedHotelItem,
                          hotelCount: hotelItems.length,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  if (hotelItems.length > 1)
                    PopupMenuButton<String>(
                      tooltip: 'Change hotel',
                      icon: const Icon(Icons.swap_horiz_rounded),
                      onSelected: (value) {
                        ref
                            .read(selectedHotelControllerProvider.notifier)
                            .selectHotel(value);
                      },
                      itemBuilder: (context) {
                        return [
                          for (final hotel in hotelItems)
                            PopupMenuItem(
                              value: hotel.id,
                              child: _WorkingHotelMenuItem(hotel: hotel),
                            ),
                        ];
                      },
                    )
                  else
                    IconButton(
                      tooltip: 'Hotel details',
                      onPressed: () {
                        _showHotelDetails(context, selectedHotelItem);
                      },
                      icon: const Icon(Icons.info_outline_rounded),
                    ),
                ],
              ),
            ),
          );
        },
        error: (error, stackTrace) {
          final fallbackId = selectedHotel.value ?? hotelIds.firstOrNull;
          final fallback = fallbackId == null
              ? null
              : _WorkingHotelItem.fallback(fallbackId);

          return ListTile(
            leading: const _HotelLeadingIcon(),
            title: Text(fallback?.displayName ?? 'Unable to load hotel'),
            subtitle: Text(
              fallback?.subtitle ?? 'Please refresh after checking the API.',
            ),
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: LinearProgressIndicator(),
        ),
      ),
    );
  }
}

class _HotelLeadingIcon extends StatelessWidget {
  const _HotelLeadingIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.brand,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: const Icon(
        Icons.apartment_rounded,
        color: Colors.white,
      ),
    );
  }
}

class _WorkingHotelMenuItem extends StatelessWidget {
  const _WorkingHotelMenuItem({required this.hotel});

  final _WorkingHotelItem hotel;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hotel.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        Text(
          '${hotel.subtitle} - ${hotel.shortCode}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

void _showHotelDetails(BuildContext context, _WorkingHotelItem hotel) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hotel.displayName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              _HotelDetailRow(
                icon: Icons.location_on_outlined,
                label: 'Address',
                value: hotel.address,
              ),
              const SizedBox(height: AppSpacing.sm),
              _HotelDetailRow(
                icon: Icons.tag_rounded,
                label: 'Hotel code',
                value: hotel.shortCode,
              ),
              if (hotel.statusLabel.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                _HotelDetailRow(
                  icon: Icons.verified_outlined,
                  label: 'Status',
                  value: hotel.statusLabel,
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _HotelDetailRow extends StatelessWidget {
  const _HotelDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.mutedInk),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.mutedInk,
                    ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(value, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class _SelectedHotelSummary extends StatelessWidget {
  const _SelectedHotelSummary({
    required this.hotel,
    required this.hotelCount,
  });

  final _WorkingHotelItem hotel;
  final int hotelCount;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        _HotelInfoPill(
          icon: Icons.location_on_outlined,
          label: hotel.subtitle,
        ),
        _HotelInfoPill(
          icon: Icons.apartment_rounded,
          label: '$hotelCount assigned hotel${hotelCount == 1 ? '' : 's'}',
        ),
        if (hotel.statusLabel.isNotEmpty)
          _HotelInfoPill(
            icon: Icons.verified_outlined,
            label: hotel.statusLabel,
          ),
      ],
    );
  }
}

class _HotelInfoPill extends StatelessWidget {
  const _HotelInfoPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.mutedInk),
          const SizedBox(width: AppSpacing.xxs),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkingHotelItem {
  const _WorkingHotelItem({
    required this.id,
    required this.displayName,
    required this.subtitle,
    required this.address,
    required this.shortCode,
    required this.statusLabel,
  });

  final String id;
  final String displayName;
  final String subtitle;
  final String address;
  final String shortCode;
  final String statusLabel;

  factory _WorkingHotelItem.fromWorkingHotel(WorkingHotel hotel) {
    final city = hotel.city.trim();
    final addressLine = hotel.addressLine.trim();
    final addressParts = [
      if (city.isNotEmpty) city,
      if (addressLine.isNotEmpty) addressLine,
    ];

    return _WorkingHotelItem(
      id: hotel.id.toString(),
      displayName: hotel.displayName.toString(),
      subtitle: city.isEmpty ? hotel.shortCode.toString() : city,
      address:
          addressParts.isEmpty ? hotel.shortCode : addressParts.join(' - '),
      shortCode: hotel.shortCode.toString(),
      statusLabel: [
        if (hotel.approvalStatus.isNotEmpty) hotel.approvalStatus,
        if (hotel.publicationStatus.isNotEmpty) hotel.publicationStatus,
      ].join(' / '),
    );
  }

  factory _WorkingHotelItem.fallback(String id) {
    return _WorkingHotelItem(
      id: id,
      displayName: _fallbackHotelLabel(id),
      subtitle: 'Hotel scope',
      address: 'Hotel scope',
      shortCode: _fallbackHotelLabel(id),
      statusLabel: '',
    );
  }
}

String _shortHotelId(String id) {
  if (id.length <= 12) {
    return id;
  }

  return 'Hotel ${id.substring(0, 8)}';
}

String _fallbackHotelLabel(String id) {
  return 'Assigned hotel (${_shortHotelId(id).replaceFirst('Hotel ', '')})';
}
