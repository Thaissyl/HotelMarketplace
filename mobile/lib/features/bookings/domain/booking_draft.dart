import '../../marketplace/domain/marketplace_models.dart';

class BookingDraft {
  const BookingDraft({
    required this.hotel,
    required this.roomType,
    required this.query,
  });

  final HotelDetail hotel;
  final AvailableRoomType roomType;
  final HotelSearchQuery query;

  int get nights => roomType.nights;

  double get estimatedTotal => roomType.totalPriceForStay;
}
