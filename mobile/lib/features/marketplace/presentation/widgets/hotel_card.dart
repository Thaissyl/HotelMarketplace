import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/utils/app_formatters.dart';
import '../../domain/marketplace_models.dart';

class HotelCard extends StatelessWidget {
  const HotelCard({
    super.key,
    required this.hotel,
    required this.onTap,
  });

  final HotelSearchResult hotel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.outline),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Text(hotel.name, style: textTheme.titleMedium),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.xs),
                  child: SizedBox(
                    width: 124,
                    height: 112,
                    child: (hotel.coverImageUrl ?? '').isEmpty
                        ? const ColoredBox(
                            color: AppColors.surfaceSoft,
                            child: Icon(
                              Icons.image_outlined,
                              color: AppColors.subtleInk,
                              size: 40,
                            ),
                          )
                        : Image.network(
                            hotel.coverImageUrl!,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.medium,
                            errorBuilder: (context, error, stackTrace) {
                              return const ColoredBox(
                                color: AppColors.surfaceSoft,
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: AppColors.subtleInk,
                                ),
                              );
                            },
                          ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${hotel.addressLine}, ${hotel.city}',
                        style: textTheme.bodyMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'From ${AppFormatters.money(hotel.minimumPricePerNight)} per night',
                        style: textTheme.labelLarge,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${hotel.availableRoomTypeCount} available room type${hotel.availableRoomTypeCount == 1 ? '' : 's'}',
                        style: textTheme.bodyMedium,
                      ),
                      if (hotel.amenityNames.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          hotel.amenityNames.take(3).join(', '),
                          style: textTheme.bodyMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 180,
                child: FilledButton(
                  onPressed: onTap,
                  child: const Text('Select Hotel'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
