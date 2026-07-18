import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/core_providers.dart';
import '../data/marketplace_api.dart';
import '../domain/marketplace_models.dart';

final marketplaceApiProvider = Provider<MarketplaceApi>((ref) {
  return MarketplaceApi(ref.watch(apiClientProvider));
});

final defaultHotelSearchQueryProvider = Provider<HotelSearchQuery>((ref) {
  final today = DateTime.now();
  final checkInDate = DateTime(
    today.year,
    today.month,
    today.day,
  ).add(const Duration(days: 1));

  return HotelSearchQuery(
    location: '',
    checkInDate: checkInDate,
    checkOutDate: checkInDate.add(const Duration(days: 1)),
    guestCount: 2,
    roomCount: 1,
  );
});

final hotelSearchQueryProvider = StateProvider<HotelSearchQuery>((ref) {
  return ref.watch(defaultHotelSearchQueryProvider);
});

final hotelSearchResultsProvider = FutureProvider.autoDispose
    .family<List<HotelSearchResult>, HotelSearchQuery>(
  (ref, query) {
    return ref.watch(marketplaceApiProvider).searchHotels(query);
  },
);

class HotelDetailRequest {
  const HotelDetailRequest({
    required this.hotelId,
    required this.query,
  });

  final String hotelId;
  final HotelSearchQuery query;

  @override
  bool operator ==(Object other) {
    return other is HotelDetailRequest &&
        other.hotelId == hotelId &&
        other.query == query;
  }

  @override
  int get hashCode => Object.hash(hotelId, query);
}

final hotelDetailProvider =
    FutureProvider.autoDispose.family<HotelDetail, HotelDetailRequest>(
  (ref, request) {
    return ref.watch(marketplaceApiProvider).getHotelDetail(
          hotelId: request.hotelId,
          query: request.query,
        );
  },
);
