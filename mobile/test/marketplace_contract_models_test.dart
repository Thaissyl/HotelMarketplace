import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_marketplace_mobile/features/marketplace/domain/marketplace_models.dart';

void main() {
  test('parses complete hotel marketplace content contract', () {
    final result = HotelSearchResult.fromJson({
      'id': 'hotel-1',
      'name': 'Contract Suites',
      'city': 'Da Nang',
      'addressLine': '1 River Street',
      'description': 'A complete hotel listing.',
      'coverImageUrl': 'https://images.example.com/cover.jpg',
      'amenityNames': ['Wi-Fi', 'Pool'],
      'minimumPricePerNight': 175,
      'availableRoomTypeCount': 1,
    });

    final detail = HotelDetail.fromJson({
      'id': 'hotel-1',
      'name': 'Contract Suites',
      'city': 'Da Nang',
      'addressLine': '1 River Street',
      'description': 'A complete hotel listing.',
      'contactEmail': 'hotel@example.com',
      'contactPhone': '0900000000',
      'checkInDate': '2026-08-20',
      'checkOutDate': '2026-08-23',
      'guestCount': 3,
      'roomCount': 1,
      'images': [
        {
          'id': 'image-1',
          'imageUrl': 'https://images.example.com/gallery.jpg',
          'displayOrder': 0,
        },
      ],
      'amenities': [
        {
          'id': 'amenity-1',
          'code': 'WIFI',
          'name': 'Wi-Fi',
          'type': 'Connectivity',
        },
      ],
      'cancellationPolicy': {
        'id': 'policy-1',
        'name': 'Flexible 48 hours',
        'freeCancellationHours': 48,
        'refundPercentage': 80,
        'description': 'Cancel early for a partial refund.',
      },
      'availableRoomTypes': [
        {
          'id': 'room-type-1',
          'name': 'Family Residence',
          'adultCapacity': 2,
          'childCapacity': 2,
          'totalGuestCapacity': 4,
          'basePricePerNight': 175,
          'availableRoomCount': 2,
          'requestedRoomCount': 1,
          'nights': 3,
          'totalPriceForStay': 525,
          'description': 'Private residence.',
          'facilities': 'Wi-Fi, workspace, minibar',
        },
      ],
    });

    expect(result.coverImageUrl, endsWith('cover.jpg'));
    expect(result.amenityNames, ['Wi-Fi', 'Pool']);
    expect(detail.images.single.displayOrder, 0);
    expect(detail.amenities.single.type, 'Connectivity');
    expect(detail.cancellationPolicy?.refundPercentage, 80);
    expect(detail.availableRoomTypes.single.facilities, contains('workspace'));
  });
}
