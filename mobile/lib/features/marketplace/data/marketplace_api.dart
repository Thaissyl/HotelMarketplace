import '../../../core/network/api_client.dart';
import '../domain/marketplace_models.dart';

class MarketplaceApi {
  MarketplaceApi(this._apiClient);

  final ApiClient _apiClient;

  Future<List<HotelSearchResult>> searchHotels(HotelSearchQuery query) {
    return _apiClient.get<List<HotelSearchResult>>(
      '/api/public/hotels',
      queryParameters: query.toQueryParameters(),
      decoder: (data) {
        if (data is! List) {
          return const <HotelSearchResult>[];
        }

        return data.map(HotelSearchResult.fromJson).toList(growable: false);
      },
    );
  }

  Future<HotelDetail> getHotelDetail({
    required String hotelId,
    required HotelSearchQuery query,
  }) {
    return _apiClient.get<HotelDetail>(
      '/api/public/hotels/$hotelId',
      queryParameters: query.toQueryParameters(),
      decoder: HotelDetail.fromJson,
    );
  }
}
