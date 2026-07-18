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
    required this.saved,
    required this.onToggleSaved,
  });

  final HotelSearchResult hotel;
  final VoidCallback onTap;
  final bool saved;
  final VoidCallback onToggleSaved;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 92,
                height: 104,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  color: AppColors.brand,
                ),
                child: const Icon(
                  Icons.apartment_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(hotel.name, style: textTheme.titleMedium),
                        ),
                        IconButton(
                          tooltip: saved ? 'Remove saved hotel' : 'Save hotel',
                          onPressed: onToggleSaved,
                          icon: Icon(
                            saved
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: saved ? AppColors.danger : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '${hotel.city} - ${hotel.addressLine}',
                      style: textTheme.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if ((hotel.description ?? '').isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        hotel.description!,
                        style: textTheme.bodyMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'From ${AppFormatters.money(hotel.minimumPricePerNight)} / night',
                            style: textTheme.labelLarge,
                          ),
                        ),
                        Text(
                          hotel.availableRoomTypeCount == 1
                              ? '1 room type'
                              : '${hotel.availableRoomTypeCount} room types',
                          style: textTheme.labelMedium,
                        ),
                      ],
                    ),
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
