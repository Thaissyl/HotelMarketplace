import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../auth/application/auth_controller.dart';
import '../../application/selected_hotel_controller.dart';

class HotelScopeSelector extends ConsumerWidget {
  const HotelScopeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hotelIds =
        ref.watch(authControllerProvider).userSession?.hotelIds ?? const [];
    final selectedHotel = ref.watch(selectedHotelControllerProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
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
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: selectedHotel.when(
                data: (hotelId) {
                  if (hotelIds.isEmpty) {
                    return Text(
                      'No hotel scope assigned',
                      style: Theme.of(context).textTheme.labelLarge,
                    );
                  }

                  return DropdownButtonFormField<String>(
                    initialValue: hotelId ?? hotelIds.first,
                    decoration: const InputDecoration(
                      labelText: 'Working hotel',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                    ),
                    items: [
                      for (final id in hotelIds)
                        DropdownMenuItem(
                          value: id,
                          child: Text(_shortHotelId(id)),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        ref
                            .read(selectedHotelControllerProvider.notifier)
                            .selectHotel(value);
                      }
                    },
                  );
                },
                error: (error, stackTrace) => Text(
                  'Unable to load hotel scope',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                loading: () => const LinearProgressIndicator(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _shortHotelId(String id) {
    if (id.length <= 12) {
      return id;
    }

    return 'Hotel ${id.substring(0, 8)}';
  }
}
