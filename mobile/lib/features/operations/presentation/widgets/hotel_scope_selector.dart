import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/srs_screen.dart';
import '../../../auth/application/auth_controller.dart';
import '../../application/operations_providers.dart';
import '../../application/selected_hotel_controller.dart';
import '../../domain/operations_models.dart';

class HotelScopeSelector extends ConsumerWidget {
  const HotelScopeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignedHotelIds =
        ref.watch(authControllerProvider).userSession?.hotelIds ?? const [];
    final selectedHotel = ref.watch(selectedHotelControllerProvider);
    final workingHotels = ref.watch(workingHotelsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SrsFieldLabel('Hotel Selector'),
        workingHotels.when(
          data: (hotels) {
            final items = _buildItems(hotels, assignedHotelIds);
            if (items.isEmpty) {
              return const _HotelSelectorMessage(
                message: 'No hotel has been assigned to this account.',
              );
            }

            final requestedHotelId = selectedHotel.value;
            final selectedHotelId =
                items.any((item) => item.id == requestedHotelId)
                    ? requestedHotelId!
                    : items.first.id;

            if (selectedHotelId != requestedHotelId) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ref
                    .read(selectedHotelControllerProvider.notifier)
                    .selectHotel(selectedHotelId);
              });
            }

            return DropdownButtonFormField<String>(
              key: ValueKey(selectedHotelId),
              initialValue: selectedHotelId,
              isExpanded: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.apartment_outlined),
              ),
              items: [
                for (final item in items)
                  DropdownMenuItem<String>(
                    value: item.id,
                    child: Text(
                      item.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: items.length == 1
                  ? null
                  : (hotelId) {
                      if (hotelId != null) {
                        ref
                            .read(selectedHotelControllerProvider.notifier)
                            .selectHotel(hotelId);
                      }
                    },
            );
          },
          error: (error, stackTrace) => const _HotelSelectorMessage(
            message: 'Hotel information is temporarily unavailable.',
          ),
          loading: () => const SizedBox(
            height: 56,
            child: Center(child: LinearProgressIndicator()),
          ),
        ),
      ],
    );
  }

  List<_HotelSelectorItem> _buildItems(
    List<WorkingHotel> hotels,
    List<String> assignedHotelIds,
  ) {
    final loadedItems = hotels
        .where((hotel) => hotel.id.isNotEmpty)
        .map(
          (hotel) => _HotelSelectorItem(
            id: hotel.id,
            displayName: hotel.displayName.trim().isEmpty
                ? 'Assigned hotel'
                : hotel.displayName.trim(),
          ),
        )
        .toList(growable: true);

    for (final hotelId in assignedHotelIds) {
      if (loadedItems.every((hotel) => hotel.id != hotelId)) {
        loadedItems.add(
          _HotelSelectorItem(
            id: hotelId,
            displayName: 'Assigned hotel',
          ),
        );
      }
    }

    return loadedItems;
  }
}

class _HotelSelectorMessage extends StatelessWidget {
  const _HotelSelectorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(message),
    );
  }
}

class _HotelSelectorItem {
  const _HotelSelectorItem({
    required this.id,
    required this.displayName,
  });

  final String id;
  final String displayName;
}
